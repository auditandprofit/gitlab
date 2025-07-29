# frozen_string_literal: true

module EE
  module Groups
    module TransferService
      include ::Search::Elastic::VulnerabilityManagementHelper
      extend ::Gitlab::Utils::Override

      PROJECT_QUERY_BATCH_SIZE = 1000

      override :ensure_allowed_transfer
      def ensure_allowed_transfer
        super

        raise_transfer_error(:saml_provider_or_scim_token_present) if saml_provider_or_scim_token_present?
      end

      override :localized_error_messages
      def localized_error_messages
        { saml_provider_or_scim_token_present:
          s_('TransferGroup|SAML Provider or SCIM Token is configured for this group.') }
          .merge(super).freeze
      end

      private

      override :add_owner_on_transferred_group
      def add_owner_on_transferred_group
        return super unless ::Namespaces::FreeUserCap::Enforcement.new(group).enforce_cap?

        ::Members::Groups::CreatorService.add_member(group, current_user, :owner, ignore_user_limits: true)
      end

      def saml_provider_or_scim_token_present?
        group.saml_provider.present? || group.scim_auth_access_token.present?
      end

      override :post_update_hooks
      def post_update_hooks(updated_project_ids, old_root_ancestor_id)
        super

        # When a group is moved to a new group, there is no way to know whether the group was using Elasticsearch
        # before the transfer. If Elasticsearch limit indexing is enabled, the group has the ES cache invalidated.
        elasticsearch_limit_indexing_enabled = ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
        group.invalidate_elasticsearch_indexes_cache! if elasticsearch_limit_indexing_enabled
        zoekt_enabled = ::Search::Zoekt.licensed_and_indexing_enabled?

        # If zoekt is not enabled then we must not do db query as we will skip all zoekt related steps
        old_namespace_had_zoekt_enabled = ::Namespace.find_by_id(old_root_ancestor_id)&.use_zoekt? if zoekt_enabled

        group.all_projects.each_batch(of: PROJECT_QUERY_BATCH_SIZE) do |projects|
          projects.each do |project|
            if zoekt_enabled && old_root_ancestor_id != project.root_namespace.id
              process_zoekt_project(old_root_ancestor_id, old_namespace_had_zoekt_enabled, project)
            end

            process_elasticsearch_project(project, elasticsearch_limit_indexing_enabled)
            delete_vulnerabilities_with_old_routing(project)
          end
        end

        process_wikis(group)

        process_group_associations(old_root_ancestor_id, group) # Epics and WorkItems

        sync_security_policies(group, current_user)
      end

      def sync_security_policies(group, current_user)
        return unless group.licensed_feature_available?(:security_orchestration_policies)
        return if ::Feature.disabled?(:security_policies_group_transfer_sync, group)

        ::Security::Policies::GroupTransferWorker.perform_async(group.id, current_user.id)
      end

      def update_project_settings(updated_project_ids)
        ::ProjectSetting.for_projects(updated_project_ids).update_all(legacy_open_source_license_available: false)
      end

      def process_zoekt_project(old_root_ancestor_id, old_namespace_had_zoekt_enabled, project)
        if old_namespace_had_zoekt_enabled
          ::Search::Zoekt.delete_async(project.id, root_namespace_id: old_root_ancestor_id)
        end

        ::Search::Zoekt.index_async(project.id) if project.use_zoekt?
      end

      def process_elasticsearch_project(project, elasticsearch_limit_indexing_enabled)
        # When a group is moved to a new group, there is no way to know whether the group was using Elasticsearch
        # before the transfer. If Elasticsearch limit indexing is enabled, each project has the ES cache invalidated.
        project.invalidate_elasticsearch_indexes_cache! if elasticsearch_limit_indexing_enabled
        # Reindex all projects and associated data to make sure the namespace_ancestry field gets
        # updated in each document.
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project) if project.maintaining_elasticsearch?
      end

      def process_group_associations(old_root_ancestor_id, group)
        return unless group.use_elasticsearch?

        if group.licensed_feature_available?(:epics)
          group.self_and_descendants.each_batch do |group_batch|
            ::Epic.in_selected_groups(group_batch).each_batch do |epics|
              ::Elastic::ProcessInitialBookkeepingService.track!(*epics)
            end
          end
        end

        return if old_root_ancestor_id == group.root_ancestor.id

        ::Search::ElasticGroupAssociationDeletionWorker.perform_async(group.id, old_root_ancestor_id,
          { include_descendants: true })
      end

      def process_wikis(group)
        return unless group.use_elasticsearch?

        group.self_and_descendants.find_each.with_index do |grp, idx|
          interval = idx % ElasticWikiIndexerWorker::MAX_JOBS_PER_HOUR
          ElasticWikiIndexerWorker.perform_in(interval, grp.id, grp.class.name, { 'force' => true })
        end
      end

      override :transfer_status_data
      def transfer_status_data(old_root_ancestor_id)
        return unless old_root_ancestor_id

        old_root_ancestor = ::Group.find_by_id(old_root_ancestor_id)
        new_root_namespace = new_parent_group&.root_ancestor || group

        if group_is_already_root?
          # When the group is already root, we need first to copy the lifecycles from the old root namespace
          # to the new root namespace, and then adjust the statuses to the new root namespace
          ::WorkItems::Widgets::Statuses::TransferLifecycleService.new(
            old_root_namespace: old_root_ancestor,
            new_root_namespace: new_root_namespace
          ).execute
        end

        group.all_projects.each_batch(of: PROJECT_QUERY_BATCH_SIZE) do |projects|
          # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- There is a limit from each_batch, for better performance
          project_namespace_ids = projects.pluck(:project_namespace_id)
          transfer_statuses(old_root_ancestor, new_root_namespace, project_namespace_ids)
          # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
        end
      end

      override :remove_paid_features_for_projects
      def remove_paid_features_for_projects(old_root_ancestor_id)
        return if old_root_ancestor_id == group.root_ancestor.id

        group.all_projects.each_batch(of: PROJECT_QUERY_BATCH_SIZE) do |projects|
          projects.each do |project|
            ::EE::Projects::RemovePaidFeaturesService.new(project).execute(new_parent_group)
          end
        end
      end

      def transfer_statuses(old_root_ancestor, new_root_namespace, project_namespace_ids)
        ::WorkItems::Widgets::Statuses::TransferService.new(
          old_root_namespace: old_root_ancestor,
          # Reset to include lifecycles created in previous iterations
          new_root_namespace: new_root_namespace.reset,
          project_namespace_ids: project_namespace_ids
        ).execute
      end
    end
  end
end
