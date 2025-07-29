# frozen_string_literal: true

module EE
  # Group EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be included in the `Group` model
  module Group
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include TokenAuthenticatable
      include InsightsFeature
      include HasWiki
      include ::WebHooks::HasWebHooks
      include CanMoveRepositoryStorage
      include ReactiveCaching
      include ::WorkItems::Parent
      include Elastic::MaintainElasticsearchOnGroupUpdate
      include ProductAnalyticsHelpers

      ALLOWED_ACTIONS_TO_USE_FILTERING_OPTIMIZATION = [:read_epic, :read_confidential_epic, :read_work_item, :read_confidential_issues].freeze
      EPIC_BATCH_SIZE = 500

      self.reactive_cache_work_type = :no_dependency
      self.reactive_cache_refresh_interval = 10.minutes
      self.reactive_cache_lifetime = 1.hour

      add_authentication_token_field :saml_discovery_token, insecure: true, unique: false, token_generator: -> { Devise.friendly_token(8) } # rubocop:disable Gitlab/TokenWithoutPrefix -- wontfix; not used for authentication

      has_many :epics
      has_many :epic_boards, class_name: 'Boards::EpicBoard', inverse_of: :group
      has_many :iterations
      has_many :iterations_cadences, class_name: 'Iterations::Cadence'
      has_one :saml_provider
      has_many :ip_restrictions, autosave: true
      has_many :protected_environments, inverse_of: :group
      has_one :insight, foreign_key: :namespace_id
      has_one :value_stream_dashboard_aggregation, class_name: 'Analytics::ValueStreamDashboard::Aggregation', foreign_key: :namespace_id
      accepts_nested_attributes_for :insight, allow_destroy: true
      has_one :analytics_dashboards_pointer, class_name: 'Analytics::DashboardsPointer', foreign_key: :namespace_id
      accepts_nested_attributes_for :analytics_dashboards_pointer, allow_destroy: true
      accepts_nested_attributes_for :value_stream_dashboard_aggregation, update_only: true
      has_one :analytics_dashboards_configuration_project, through: :analytics_dashboards_pointer, source: :target_project
      # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
      has_one :index_status, class_name: 'Elastic::GroupIndexStatus', foreign_key: :namespace_id, dependent: :destroy
      # rubocop:enable Cop/ActiveRecordDependent -- legacy usage
      has_one :google_cloud_platform_workload_identity_federation_integration, class_name: 'Integrations::GoogleCloudPlatform::WorkloadIdentityFederation'
      has_one :amazon_q_integration, class_name: 'Integrations::AmazonQ'
      has_one :vulnerability_namespace_statistic, class_name: 'Vulnerabilities::NamespaceStatistic', foreign_key: :namespace_id, inverse_of: :group
      has_many :external_audit_event_destinations, class_name: "AuditEvents::ExternalAuditEventDestination", foreign_key: 'namespace_id'
      has_many :external_audit_event_streaming_destinations, class_name: "AuditEvents::Group::ExternalStreamingDestination", foreign_key: 'group_id'
      has_many :google_cloud_logging_configurations, class_name: "AuditEvents::GoogleCloudLoggingConfiguration",
        foreign_key: 'namespace_id',
        inverse_of: :group
      has_many :amazon_s3_configurations, class_name: "AuditEvents::AmazonS3Configuration",
        foreign_key: 'namespace_id',
        inverse_of: :group

      has_many :ldap_group_links, foreign_key: 'group_id', dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
      has_many :saml_group_links, foreign_key: 'group_id'
      has_many :hooks, class_name: 'GroupHook'

      has_many :allowed_email_domains, -> { order(id: :asc) }, autosave: true

      has_many :scim_identities, class_name: 'GroupScimIdentity'
      has_one :scim_auth_access_token, class_name: 'GroupScimAuthAccessToken'

      # We cannot simply set `has_many :audit_events, as: :entity, dependent: :destroy`
      # here since Group inherits from Namespace, the entity_type would be set to `Namespace`.
      has_many :audit_events, -> { where(entity_type: ::Group.name) }, foreign_key: 'entity_id'

      has_many :project_templates, through: :projects, foreign_key: 'custom_project_templates_group_id'

      has_many :managed_users, class_name: 'User', foreign_key: 'managing_group_id', inverse_of: :managing_group
      has_many :enterprise_user_details, class_name: 'UserDetail', foreign_key: 'enterprise_group_id', inverse_of: :enterprise_group
      has_many :enterprise_users, through: :enterprise_user_details, source: :user
      has_many :provisioned_user_details, class_name: 'UserDetail', foreign_key: 'provisioned_by_group_id', inverse_of: :provisioned_by_group
      has_many :provisioned_users, through: :provisioned_user_details, source: :user
      has_one :group_merge_request_approval_setting, inverse_of: :group

      has_one :group_wiki_repository
      has_many :repository_storage_moves, class_name: 'Groups::RepositoryStorageMove', inverse_of: :container

      has_many :epic_board_recent_visits, class_name: 'Boards::EpicBoardRecentVisit', inverse_of: :group
      has_many :ssh_certificates, inverse_of: :group, foreign_key: :namespace_id, class_name: 'Groups::SshCertificate'

      belongs_to :file_template_project, class_name: "Project"

      belongs_to :push_rule, inverse_of: :group
      has_many :approval_rules, class_name: 'ApprovalRules::ApprovalGroupRule', inverse_of: :group

      has_many :saved_replies, class_name: 'Groups::SavedReply'

      has_many :security_exclusions, class_name: 'Security::GroupSecurityExclusion'

      # WIP v2 approval rules as part of https://gitlab.com/groups/gitlab-org/-/epics/12955
      has_many :v2_approval_rules_groups, class_name: 'MergeRequests::ApprovalRulesGroup', inverse_of: :group
      has_many :v2_approval_rules, through: :v2_approval_rules_groups, class_name: 'MergeRequests::ApprovalRule', source: :approval_rule

      has_many :subscription_seat_assignments, class_name: 'GitlabSubscriptions::SeatAssignment', foreign_key: :namespace_id

      has_many :analyzer_group_statuses, class_name: 'Security::AnalyzerNamespaceStatus', foreign_key: :namespace_id, inverse_of: :namespace
      has_many :ai_feature_settings, class_name: 'Ai::ModelSelection::NamespaceFeatureSetting', foreign_key: :namespace_id, inverse_of: :namespace

      delegate :repository_read_only,
        :default_compliance_framework,
        :default_compliance_framework_id,
        to: :namespace_settings, allow_nil: true

      delegate :duo_availability, :duo_availability=, to: :namespace_settings
      delegate :experiment_settings_allowed?, :prompt_cache_settings_allowed?, to: :namespace_settings
      delegate :user_cap_enabled?, to: :namespace_settings

      delegate :disable_personal_access_tokens=, to: :namespace_settings
      delegate :enterprise_users_extensions_marketplace_enabled=, to: :namespace_settings

      delegate :wiki_access_level, :wiki_access_level=, to: :group_feature, allow_nil: true

      delegate :extended_grat_expiry_webhooks_execute, :extended_grat_expiry_webhooks_execute=, to: :namespace_settings

      delegate :disable_invite_members, :disable_invite_members=, to: :namespace_settings
      delegate :disable_invite_members?, to: :namespace_settings

      # Use +checked_file_template_project+ instead, which implements important
      # visibility checks
      private :file_template_project

      validates :repository_size_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

      validates :max_personal_access_token_lifetime,
        allow_blank: true,
        numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: :max_auth_lifetime }

      validate :custom_project_templates_group_allowed, if: :custom_project_templates_group_id_changed?

      scope :with_saml_provider, -> { preload(:saml_provider) }
      scope :with_saml_group_links, -> { joins(:saml_group_links) }

      scope :where_group_links_with_provider, ->(provider) do
        joins(:ldap_group_links).where(ldap_group_links: { provider: provider })
      end

      scope :invited_groups_in_groups_for_hierarchy, ->(group, exclude_guests = false) do
        guests_scope = exclude_guests ? ::GroupGroupLink.non_guests : ::GroupGroupLink.all

        joins(:shared_group_links)
          .where(group_group_links: { shared_group_id: group.self_and_descendants })
          .merge(guests_scope)
      end

      scope :invited_groups_with_guest_member_role, ->(group) do
        joins(:shared_group_links)
          .where(group_group_links: { shared_group_id: group.self_and_descendants })
          .merge(::GroupGroupLink.guests.with_custom_role)
      end

      scope :invited_groups_in_projects_for_hierarchy, ->(group, exclude_guests = false) do
        guests_scope = exclude_guests ? ::ProjectGroupLink.non_guests : ::ProjectGroupLink.all

        joins(:project_group_links)
          .where(project_group_links: { project_id: group.all_projects })
          .merge(guests_scope)
      end

      scope :with_external_audit_event_destinations, -> do
        joins(:external_audit_event_destinations)
      end

      scope :with_managed_accounts_enabled, -> do
        joins(:saml_provider).where(saml_providers:
          {
            enabled: true,
            enforced_sso: true,
            enforced_group_managed_accounts: true
          })
      end

      scope :with_no_pat_expiry_policy, -> { where(max_personal_access_token_lifetime: nil) }

      scope :with_project_templates, -> { where.not(custom_project_templates_group_id: nil) }

      scope :with_custom_file_templates, -> do
        preload(
          file_template_project: :route,
          projects: :route,
          shared_projects: :route
        ).where.not(file_template_project_id: nil)
      end

      # Returns groups with public or internal visibility_level.
      # Used by Group.groups_user_can method to include groups
      # where user access_level does not need to be checked.
      scope :not_private, -> { where('visibility_level > ?', ::Gitlab::VisibilityLevel::PRIVATE) }

      scope :for_epics, ->(epics) do
        epics_query = epics.select(:group_id)
        joins("INNER JOIN (#{epics_query.to_sql}) as epics on epics.group_id = namespaces.id")
      end

      scope :user_is_member, ->(user) { id_in(user.authorized_groups(with_minimal_access: false)) }

      scope :with_trial_started_on, ->(date) do
        left_joins(:gitlab_subscription).where(gitlab_subscriptions: { trial: true, trial_starts_on: date })
      end

      scope :by_repository_storage, ->(storage) do
        joins(group_wiki_repository: :shard).where(shards: { name: storage })
      end

      state_machine :ldap_sync_status, namespace: :ldap_sync, initial: :ready do
        state :ready
        state :started
        state :pending
        state :failed

        event :pending do
          transition [:ready, :failed] => :pending
        end

        event :start do
          transition [:ready, :pending, :failed] => :started
        end

        event :finish do
          transition started: :ready
        end

        event :fail do
          transition started: :failed
        end

        after_transition ready: :started do |group, _|
          group.ldap_sync_last_sync_at = DateTime.current
          group.save
        end

        after_transition started: :ready do |group, _|
          current_time = DateTime.current
          group.ldap_sync_last_update_at = current_time
          group.ldap_sync_last_successful_update_at = current_time
          group.ldap_sync_error = nil
          group.save
        end

        after_transition started: :failed do |group, _|
          group.ldap_sync_last_update_at = DateTime.current
          group.save
        end
      end

      def max_auth_lifetime
        # See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/153876#note_2099583889 for no actor discussion
        # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Unable to reliably find actor from Group or PAT usages
        if ::Feature.enabled?(:buffered_token_expiration_limit)
          400
        else
          365
        end
        # rubocop:enable Gitlab/FeatureFlagWithoutActor
      end

      def enforced_group_managed_accounts?
        !!saml_provider&.enforced_group_managed_accounts?
      end

      def enforced_sso?
        !!saml_provider&.enforced_sso?
      end

      def repository_read_only?
        !!namespace_settings&.repository_read_only?
      end

      def unique_project_download_limit_enabled?
        root? && licensed_feature_available?(:unique_project_download_limit)
      end

      def service_accounts
        provisioned_users.service_account
      end
    end

    override :supports_saved_replies?
    def supports_saved_replies?
      licensed_feature_available?(:group_saved_replies)
    end

    def licensed_ai_features_available?
      licensed_feature_available?(:ai_features) || licensed_feature_available?(:ai_chat)
    end

    def licensed_duo_core_features_available?
      licensed_feature_available?(:code_suggestions) || licensed_feature_available?(:ai_chat)
    end

    override :supports_group_work_items?
    def supports_group_work_items?
      # For now we only support epics as group work items. We therefore can re-use `epics` as a licensed feature check.
      licensed_feature_available?(:epics)
    end

    def work_item_epics_enabled?
      licensed_feature_available?(:epics)
    end

    def work_item_epics_ssot_enabled?
      ::Feature.enabled?(:work_item_epics_ssot, root_ancestor)
    end

    def allow_group_items_in_project_autocompletion?
      ::Feature.enabled?(:allow_group_items_in_project_autocompletion, self, type: :gitlab_com_derisk) &&
        licensed_feature_available?(:epics)
    end

    def ai_review_merge_request_allowed?(user)
      Ability.allowed?(user, :access_ai_review_mr, self) &&
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: self,
          feature_name: :review_merge_request,
          user: user
        ).allowed?
    end

    def project_epics_enabled?
      feature_flag_enabled_for_self_or_ancestor?(:project_work_item_epics, type: :beta)
    end

    class_methods do
      def groups_user_can(groups, user, action, same_root: false)
        # If :use_traversal_ids is enabled we can use filter optmization
        # to skip some permission check queries in group descendants.
        if same_root && can_use_epics_filtering_optimization?(groups, action)
          filter_groups_user_can(groups: groups, user: user, action: action)
        else
          groups = ::Gitlab::GroupPlansPreloader.new.preload(groups)

          # if we are sure that all groups have the same root group, we can
          # preset root_ancestor for all of them to avoid an additional SQL query
          # done for each group permission check:
          # https://gitlab.com/gitlab-org/gitlab/issues/11539
          preset_root_ancestor_for(groups) if same_root

          super
        end
      end

      def can_use_epics_filtering_optimization?(groups, action)
        return false unless ALLOWED_ACTIONS_TO_USE_FILTERING_OPTIMIZATION.include?(action)

        return false unless groups.any?

        groups.first.use_traversal_ids?
      end

      # Manually preloads saml_providers, which cannot be done in AR, since the
      # relationship is on the root ancestor.
      # This is required since the `:read_group` ability depends on `Group.saml_provider`
      def preload_root_saml_providers(groups)
        saml_providers = SamlProvider.where(group: groups.map(&:root_ancestor).uniq).index_by(&:group_id)

        return unless saml_providers

        groups.each do |group|
          group.root_saml_provider = saml_providers[group.root_ancestor.id]
        end
      end

      def with_api_scopes
        super()
          .preload(
            :ldap_group_links,
            :saml_group_links,
            :file_template_project,
            group_wiki_repository: :shard)
      end

      private

      # Used when all groups that user is fetching epics (or work item epics) for belongs to the same hierarchy.
      # It prevents doing one query to check user access for each group which causes
      # timeouts on big hierarchies.
      # Instead of iterating over all groups over policies we perform a union of queries
      # to get all groups that users can read epics / work item epics with:
      #
      #  1 fragment takes all groups via direct authorization
      #  1 fragment to take groups authorized by shares
      #  1 to get groups authorized via project membership
      #  1 to get public/internal groups within the hierarchy
      #
      # More information at https://gitlab.com/gitlab-org/gitlab/-/issues/367868#note_1027151497
      def filter_groups_user_can(groups:, user:, action:)
        top_level_group = groups.first&.root_ancestor

        return ::Group.none unless top_level_group
        return ::Group.none unless top_level_group.feature_available?(:epics)

        access_level =
          if [:read_confidential_epic, :read_confidential_issues].include?(action)
            ::Gitlab::Access::PLANNER
          else
            ::Gitlab::Access::GUEST
          end

        queries_for_union = [
          hierarchy_group_ids_authorized_by_membership(user, top_level_group, access_level),
          hierarchy_group_ids_authorized_by_share(user, groups, access_level)
        ]

        if [:read_epic, :read_work_item].include?(action)
          queries_for_union << hierarchy_groups_authorized_by_project_membership(user, top_level_group)

          # Gets public and internal groups
          # Not needed if top level group is private
          queries_for_union << top_level_group.self_and_descendants.not_private.select(:id) unless top_level_group.private?
        end

        group_ids_union = ::Gitlab::SQL::Union.new(queries_for_union)

        where(id: groups.select(:id)).where("id IN (#{group_ids_union.to_sql})") # rubocop:disable GitlabSecurity/SqlInjection
      end

      def hierarchy_group_ids_authorized_by_membership(user, hierarchy_parent, access_level)
        where('traversal_ids && ARRAY(?)',
          hierarchy_parent.members_with_descendants
            .where('access_level >= ?', access_level)
            .where(user: user)
            .select(:source_id)
        ).select(:id)
      end

      def hierarchy_group_ids_authorized_by_share(user, groups_hierarchy, access_level)
        # Explicit casting can be removed once namespaces.traversal_ids is converted to bigint[]
        type_name = connection.select_value(
          "SELECT typname FROM pg_attribute INNER JOIN pg_type ON pg_attribute.atttypid = pg_type.oid " \
            "WHERE attname = 'traversal_ids' AND attrelid = 'namespaces'::regclass"
        )
        traversal_ids_type = case type_name
                             when '_int4'
                               'integer[]'
                             when '_int8'
                               'bigint[]'
                             end

        where("traversal_ids && ARRAY(?)::#{traversal_ids_type}",
          ::GroupGroupLink
            .where(shared_group_id: groups_hierarchy.select(:id))
            .where('group_access >= ?', access_level)
            .where(shared_with_group_id: ::GroupMember.where(user: user).authorizable.select(:source_id))
            .select(:shared_group_id)
        ).select(:id)
      end

      def hierarchy_groups_authorized_by_project_membership(user, hierarchy_parent)
        group_ids_that_has_projects =
          ::Project.for_group_and_its_subgroups(hierarchy_parent)
            .public_or_visible_to_user(user).select(:namespace_id)

        where(id: group_ids_that_has_projects).select('unnest(traversal_ids)')
      end
    end

    attr_writer :root_saml_provider

    def root_saml_provider
      strong_memoize(:root_saml_provider) { root_ancestor.saml_provider }
    end

    def ip_restriction_ranges
      return unless ip_restrictions.present?

      ip_restrictions.map(&:range).join(",")
    end

    def allowed_email_domains_list
      return if allowed_email_domains.empty?

      allowed_email_domains.domain_names.join(",")
    end

    def human_ldap_access
      ::Gitlab::Access.options_with_owner.key(ldap_access)
    end

    # NOTE: Backwards compatibility with old ldap situation
    def ldap_cn
      ldap_group_links.first.try(:cn)
    end

    def ldap_access
      ldap_group_links.first.try(:group_access)
    end

    override :ldap_synced?
    def ldap_synced?
      (::Gitlab.config.ldap.enabled && ldap_group_links.any?(&:active?)) || super
    end

    def mark_ldap_sync_as_failed(error_message, skip_validation: false)
      return false unless ldap_sync_started?

      error_message = ::Gitlab::UrlSanitizer.sanitize(error_message)

      if skip_validation
        # A group that does not validate cannot transition out of its
        # current state, so manually set the ldap_sync_status
        update_columns(ldap_sync_error: error_message, ldap_sync_status: 'failed')
      else
        fail_ldap_sync
        update_column(:ldap_sync_error, error_message)
      end
    end

    # This token conveys that the anonymous user is allowed to know of the group
    # Used to avoid revealing that a group exists on a given path
    def saml_discovery_token
      ensure_saml_discovery_token!
    end

    def saml_enabled?
      group_saml_enabled? || global_saml_enabled?
    end

    def saml_group_sync_available?
      feature_available?(:saml_group_sync) && root_ancestor.saml_enabled?
    end

    def group_saml_enabled?
      return false unless saml_provider && ::Gitlab::Auth::GroupSaml::Config.enabled?

      saml_provider.persisted? && saml_provider.enabled?
    end

    def saml_group_links_exists?
      saml_group_links.exists?
    end

    def global_saml_enabled?
      ::Gitlab::Auth::Saml::Config.enabled?
    end

    def jira_issues_integration_available?
      feature_available?(:jira_issues_integration)
    end

    def multiple_approval_rules_available?
      feature_available?(:multiple_approval_rules)
    end

    override :multiple_issue_boards_available?
    def multiple_issue_boards_available?
      feature_available?(:multiple_group_issue_boards)
    end

    def group_project_template_available?
      feature_available?(:group_project_templates)
    end

    def scoped_variables_available?
      feature_available?(:group_scoped_ci_variables)
    end

    def first_non_empty_project
      all_children_projects = self.projects_for_group_and_its_subgroups_without_deleted
      all_children_projects.detect { |project| !project.empty_repo? }
    end

    def root_ancestor_ip_restrictions
      return ip_restrictions if parent_id.nil?

      root_ancestor.ip_restrictions
    end

    def root_ancestor_allowed_email_domains
      return allowed_email_domains if parent_id.nil?

      root_ancestor.allowed_email_domains
    end

    def owner_of_email?(email)
      return false unless domain_verification_available?

      email_domain = Mail::Address.new(email).domain&.downcase
      return false unless email_domain

      all_projects_pages_domains(only_verified: true).find_by_domain_case_insensitive(email_domain).present?
    end

    # Overrides a method defined in `::EE::Namespace`
    override :checked_file_template_project
    def checked_file_template_project(*args, &blk)
      project = file_template_project(*args, &blk)

      return unless project && (
          project_ids.include?(project.id) || shared_project_ids.include?(project.id))

      # The license check would normally be the cheapest to perform, so would
      # come first. In this case, the method is carefully designed to perform
      # no SQL at all, but `feature_available?` will cause an ApplicationSetting
      # to be created if it doesn't already exist! This is mostly a problem in
      # the specs, but best avoided in any case.
      return unless feature_available?(:custom_file_templates_for_namespace)

      project
    end

    override :block_seat_overages?
    def block_seat_overages?
      ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) &&
        namespace_settings.seat_control_block_overages?
    end

    def seat_overage?
      return false unless gitlab_subscription

      members_count = billable_members_count_with_reactive_cache

      return false unless members_count

      gitlab_subscription.seats < members_count
    end

    def calculate_reactive_cache
      billable_members_count
    end

    def billable_members_count_with_reactive_cache
      with_reactive_cache do |return_value|
        return_value
      end
    end

    override :billable_members_count
    def billable_members_count(requested_hosted_plan = nil)
      billable_ids = billed_user_ids(requested_hosted_plan)

      billable_ids[:user_ids].count
    end

    # For now, we are not billing for members with a Guest role for subscriptions
    # with a Gold/Ultimate plan. The other plans will treat Guest members as a regular member
    # for billing purposes.
    #
    # For the user_ids key, we are plucking the user_ids from the "Members" table in an array and
    # converting the array of user_ids to a Set which will have unique user_ids.
    override :billed_user_ids
    def billed_user_ids(requested_hosted_plan = nil)
      exclude_guests?(requested_hosted_plan) ? billed_user_ids_excluding_guests : billed_user_ids_including_guests
    end

    override :supports_events?
    def supports_events?
      feature_available?(:epics)
    end

    override :exclude_guests?
    def exclude_guests?(requested_hosted_plan = nil)
      (
        [actual_plan_name, requested_hosted_plan] &
          [::Plan::GOLD, ::Plan::ULTIMATE, ::Plan::ULTIMATE_TRIAL]
      ).any?
    end

    def vulnerabilities
      ::Vulnerability.where(id: Vulnerabilities::Read.by_group(self).select(:vulnerability_id).unarchived)
    end

    def vulnerability_reads
      ::Vulnerabilities::Read.by_group(self)
    end

    def next_traversal_ids
      traversal_ids.dup.tap { |ids| ids[-1] += 1 }
    end

    def vulnerability_scanners
      ::Vulnerabilities::Scanner.where(project: Vulnerabilities::Statistic.by_group(self).unarchived.select(:project_id))
    end

    def vulnerability_historical_statistics
      ::Vulnerabilities::NamespaceHistoricalStatistic.for_namespace_and_descendants(self)
    end

    def vulnerability_namespace_statistic
      super || build_vulnerability_namespace_statistic
    end

    def max_personal_access_token_lifetime_from_now
      if max_personal_access_token_lifetime.present?
        Date.current + max_personal_access_token_lifetime
      else
        ::Gitlab::CurrentSettings.max_personal_access_token_lifetime_from_now
      end
    end

    def personal_access_token_expiration_policy_available?
      enforced_group_managed_accounts? && License.feature_available?(:personal_access_token_expiration_policy)
    end

    def update_personal_access_tokens_lifetime
      return unless max_personal_access_token_lifetime.present? && personal_access_token_expiration_policy_available?

      ::PersonalAccessTokens::Groups::UpdateLifetimeService.new(self).execute
    end

    def predefined_push_rule
      strong_memoize(:predefined_push_rule) do
        next push_rule if push_rule

        if has_parent?
          parent.predefined_push_rule
        else
          PushRuleFinder.new.execute
        end
      end
    end

    def owners_emails
      self.pluck_member_user(:email, filters: { access_level: ::GroupMember::OWNER })
    end

    # this method will be delegated to namespace_settings, but as we need to wait till
    # all groups will have namespace_settings created via background migration,
    # we need to serve it from this class
    def prevent_forking_outside_group?
      return namespace_settings.prevent_forking_outside_group? if namespace_settings

      root_ancestor.saml_provider&.prohibited_outer_forks?
    end

    def service_access_tokens_expiration_enforced?
      namespace_settings.service_access_tokens_expiration_enforced if namespace_settings
    end

    def minimal_access_role_allowed?
      feature_available?(:minimal_access_role) && !has_parent?
    end

    override :member?
    def member?(user, min_access_level = minimal_member_access_level)
      return false unless user

      return super unless min_access_level == ::Gitlab::Access::MINIMAL_ACCESS
      return super unless minimal_access_role_allowed?

      ::Members::MembersWithParents
        .new(self)
        .members(minimal_access: true)
        .find_by(user_id: user.id)
        .present?
    end

    def minimal_member_access_level
      minimal_access_role_allowed? ? ::Gitlab::Access::MINIMAL_ACCESS : ::Gitlab::Access::GUEST
    end

    override :access_level_roles
    def access_level_roles
      levels = ::GroupMember.access_level_roles
      return levels unless minimal_access_role_allowed?

      levels.merge(::Gitlab::Access::MINIMAL_ACCESS_HASH)
    end

    override :users_count
    def users_count
      return all_group_members.count if minimal_access_role_allowed?

      members.count
    end

    def releases_count
      ::Release.by_namespace_id(self_and_descendants.select(:id)).count
    end

    def releases_percentage
      calculate_sql = <<~SQL
        (
          COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM releases WHERE releases.project_id = projects.id)) * 100.0 / GREATEST(COUNT(*), 1)
        )::integer AS releases_percentage
      SQL

      self.class.count_by_sql(
        ::Project.select(calculate_sql)
        .where(namespace_id: self_and_descendants.select(:id)).to_sql
      )
    end

    override :execute_hooks
    def execute_hooks(data, hooks_scope)
      super

      return unless feature_available?(:group_webhooks)

      # By default the webhook resource_access_token_hooks will execute for
      # seven_days interval but we have a setting to allow webhook execution
      # for thirty_days and sixty_days_plus interval too.
      is_extended_expiry_webhook = hooks_scope == :resource_access_token_hooks &&
        data[:interval] != :seven_days

      group_hooks = if is_extended_expiry_webhook
                      GroupHook.where(group_id: groups_for_extended_webhook_execution_on_token_expiry)
                    else
                      GroupHook.where(group_id: self_and_ancestors)
                    end

      execute_async_hooks(group_hooks, hooks_scope, data)
    end

    override :git_transfer_in_progress?
    def git_transfer_in_progress?
      reference_counter(type: ::Gitlab::GlRepository::WIKI).value > 0
    end

    def repository_storage
      group_wiki_repository&.shard_name || ::Repository.pick_storage_shard
    end

    def user_cap_reached?(use_cache: false)
      return false unless user_cap_available?

      return false unless root_ancestor.namespace_settings&.seat_control_user_cap?

      user_cap = root_ancestor.namespace_settings&.new_user_signups_cap
      return false unless user_cap

      members_count = use_cache ? root_ancestor.billable_members_count_with_reactive_cache : root_ancestor.billable_members_count
      return false unless members_count

      user_cap <= members_count
    end

    def shared_externally?
      strong_memoize(:shared_externally) do
        internal_groups = self.self_and_descendants

        group_links = self.class.invited_groups_in_groups_for_hierarchy(self)
                          .where.not(group_group_links: { shared_with_group_id: internal_groups })
                          .exists?

        project_links = self.class.invited_groups_in_projects_for_hierarchy(self)
                            .where.not(project_group_links: { group_id: internal_groups })
                            .exists?

        group_links || project_links
      end
    end

    def has_free_or_no_subscription?
      # this is a side-effect free version of checking if a namespace
      # is on a free plan or has no plan - see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/80839#note_851566461
      strong_memoize(:has_free_or_no_subscription) do
        subscription = root_ancestor.gitlab_subscription

        # there is a chance that subscriptions do not have a plan https://gitlab.com/gitlab-org/gitlab/-/merge_requests/81432#note_858514873
        if subscription&.plan_name
          subscription.plan_name == ::Plan::FREE
        else
          true
        end
      end
    end

    override :capacity_left_for_user?
    def capacity_left_for_user?(user)
      return true unless user_cap_available?
      # Bots do not take up a billable seat
      return true if user&.bot?
      return true if ::Member.in_hierarchy(root_ancestor).with_user(user).with_state(:active).exists?

      !user_cap_reached?
    end

    def enforce_free_user_cap?
      ::Namespaces::FreeUserCap::Enforcement.new(self).enforce_cap?
    end

    # Members belonging directly to Group or its subgroups
    def billed_group_users(exclude_guests: false)
      members = billed_group_members(exclude_guests: exclude_guests)
      billed_users_from_members(members)
    end

    def billed_group_members(exclude_guests: false)
      members = ::GroupMember.active_without_invites_and_requests.where(
        source_id: self_and_descendants
      )
      members = members.with_elevated_guests if exclude_guests

      members.not_banned_in(root_ancestor)
    end

    # Members belonging directly to Projects within Group or Projects within subgroups
    def billed_project_users(exclude_guests: false)
      members = billed_project_members(exclude_guests: exclude_guests, select: [:user_id])
      billed_users_from_members(members, merge_condition: ::User.with_state(:active))
        .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/417464')
    end

    def billed_project_members(exclude_guests: false, select: [])
      members = ::ProjectMember.without_invites_and_requests
        .where(source_id: ::Project.joins(:group).where(namespace: self_and_descendants))
        .not_banned_in(root_ancestor)

      if exclude_guests
        billed_elevated_guest_custom_roles_in_group_hierarchy = ::MemberRole.occupies_seat
          .by_namespace(self_and_descendants)
          .select(:id)

        billed_custom_role_members = ::ProjectMember.without_invites_and_requests
          .with_member_role_id(billed_elevated_guest_custom_roles_in_group_hierarchy)
          .not_banned_in(root_ancestor)

        ::Member.from_union([members.non_guests.select(select), billed_custom_role_members.select(select)])
      else
        members
      end
    end

    # Members belonging to Groups invited to collaborate with Groups and Subgroups
    def billed_shared_group_users(exclude_guests: false)
      members = billed_shared_group_members(exclude_guests: exclude_guests)
      billed_users_from_members(members)
    end

    def billed_shared_group_members(exclude_guests: false)
      groups = self.class.invited_groups_in_groups_for_hierarchy(self, exclude_guests)

      # gets all billable members from group-invites with access_level > GUEST
      members = invited_or_shared_group_members(groups, exclude_guests: exclude_guests)

      # gets all billable members from group-invites with access_level = GUEST + custom_role
      members_with_custom_role = billed_shared_guest_group_members_with_custom_role(exclude_guests: exclude_guests)

      # merge both and return
      # see acceptance criteria - https://gitlab.com/gitlab-org/gitlab/-/issues/443369#note_2045035173
      ::GroupMember.from_union([members, members_with_custom_role]).not_banned_in(root_ancestor)
    end

    def billed_shared_guest_group_members_with_custom_role(exclude_guests: false)
      return ::GroupMember.none unless exclude_guests
      return ::GroupMember.none unless ::Feature.enabled?(:assign_custom_roles_to_group_links_saas, self)

      # invited groups that have access_level = GUEST + custom_role
      groups = self.class.invited_groups_with_guest_member_role(self)

      # get all members from those invited groups that have
      # access_level = GUEST + custom_role (that has occupies_seat = TRUE)
      members_with_elevating_guest_member_role(groups)
    end

    # Members belonging to Groups invited to collaborate with Projects
    def billed_invited_group_to_project_users(exclude_guests: false)
      members = billed_invited_group_to_project_members(exclude_guests: exclude_guests)
      billed_users_from_members(members)
    end

    def billed_invited_group_to_project_members(exclude_guests: false)
      groups = self.class.invited_groups_in_projects_for_hierarchy(self, exclude_guests)
      invited_or_shared_group_members(groups, exclude_guests: exclude_guests).not_banned_in(root_ancestor)
    end

    # Checks if user belongs to billed_group_users
    def billed_group_user?(user, exclude_guests: false)
      billed_group_users(exclude_guests: exclude_guests).exists?(id: user.id)
    end

    # Checks if user belongs to billed_project_users
    def billed_project_user?(user, exclude_guests: false)
      billed_project_users(exclude_guests: exclude_guests).exists?(id: user.id)
    end

    # Checks if user belongs to billed_shared_group_users
    def billed_shared_group_user?(user, exclude_guests: false)
      billed_shared_group_users(exclude_guests: exclude_guests).exists?(id: user.id)
    end

    # Checks if user belongs to billed_invited_group_to_project_users
    def billed_shared_project_user?(user, exclude_guests: false)
      billed_invited_group_to_project_users(exclude_guests: exclude_guests).exists?(id: user.id)
    end

    def eligible_for_gitlab_duo_pro_seat?(user)
      billed_group_user?(user) ||
        billed_project_user?(user) ||
        billed_shared_group_user?(user) ||
        billed_shared_project_user?(user)
    end

    def gitlab_duo_eligible_user_ids
      # all billable users and guests are eligible to be assigned gitlab duo
      billed_user_ids_including_guests[:user_ids]
    end

    def parent_epic_ids_in_ancestor_groups
      ids = Set.new
      epics.has_parent.each_batch(of: EPIC_BATCH_SIZE, column: :iid) do |batch|
        ids += ::Epic.id_in(batch.select(:parent_id)).where.not(group_id: id).limit(EPIC_BATCH_SIZE).pluck(:id)
      end

      ids.to_a
    end

    def code_owner_approval_required_available?
      feature_available?(:code_owner_approval_required)
    end

    def has_dependencies?
      sbom_occurrences.exists?
    end

    def sbom_occurrences
      Sbom::Occurrence.for_namespace_and_descendants(self).unarchived
    end

    override :reached_project_access_token_limit?
    def reached_project_access_token_limit?
      actual_limits.exceeded?(:project_access_token_limit, active_project_tokens_of_root_ancestor)
    end

    def count_within_namespaces
      ::Group.where("traversal_ids @> '{?}'", id).count
    end

    # Thin wrapper to promote a source of truth for filtering billed users as we
    # filter the users from members outside this class as well.
    def billed_users_from_members(members, merge_condition: ::User.all)
      users_without_bots(members, merge_condition: merge_condition)
    end

    def assigning_role_too_high?(current_user, access_level)
      return false if current_user.can_admin_all_resources?
      return false unless access_level

      current_user_role = max_member_access(current_user)

      access_level > current_user_role
    end

    def can_manage_extensions_marketplace_for_enterprise_users?
      root? &&
        licensed_feature_available?(:disable_extensions_marketplace_for_enterprise_users) &&
        ::WebIde::ExtensionMarketplace.feature_enabled_from_application_settings?
    end

    def enterprise_users_extensions_marketplace_enabled?
      return true unless can_manage_extensions_marketplace_for_enterprise_users?

      namespace_settings.enterprise_users_extensions_marketplace_enabled?
    end

    def disable_personal_access_tokens_available?
      root? &&
        ::Gitlab::Saas.feature_available?(:disable_personal_access_tokens) &&
        licensed_feature_available?(:disable_personal_access_tokens)
    end

    # Disable personal access tokens for enterprise users of this group
    def disable_personal_access_tokens?
      disable_personal_access_tokens_available? &&
        namespace_settings.disable_personal_access_tokens?
    end

    def extended_grat_expiry_webhooks_execute?
      licensed_feature_available?(:group_webhooks) &&
        namespace_settings&.extended_grat_expiry_webhooks_execute?
    end

    def active_compliance_frameworks?
      # test default framework first since it is most likely to have projects assigned
      [[default_compliance_framework] + compliance_management_frameworks].flatten.compact.uniq.any? do |framework|
        framework.projects.any?
      end
    end

    def groups_for_extended_webhook_execution_on_token_expiry
      self_and_ancestors
        .joins(:namespace_settings)
        .where(namespace_settings: { extended_grat_expiry_webhooks_execute: true })
    end

    def virtual_registry_policy_subject
      ::VirtualRegistries::Packages::Policies::Group.new(self)
    end

    private

    def execute_async_hooks(group_hooks, hooks_scope, data)
      group_hooks.hooks_for(hooks_scope).each do |hook|
        hook.async_execute(data, hooks_scope.to_s)
      end
    end

    def active_project_tokens_of_root_ancestor
      root_ancestor_and_descendants_project_bots = ::User
        .joins(projects: :group)
        .where(namespaces: { id: root_ancestor.self_and_descendants.select(:id) })
        .project_bot
        .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/428542")

      ::PersonalAccessToken.active.joins(:user).merge(root_ancestor_and_descendants_project_bots)
    end

    override :post_create_hook
    def post_create_hook
      super

      execute_subgroup_hooks(:create)
    end

    override :post_destroy_hook
    def post_destroy_hook
      super

      execute_subgroup_hooks(:destroy)
    end

    def execute_subgroup_hooks(event)
      return unless subgroup?
      return unless feature_available?(:group_webhooks)

      run_after_commit do
        data = ::Gitlab::HookData::SubgroupBuilder.new(self).build(event)
        # Imagine a case where a subgroup has a webhook with `subgroup_events` enabled.
        # When this subgroup is removed, there is no point in this subgroup's webhook itself being notified
        # that `self` was removed. Rather, we should only care about notifying its ancestors
        # and hence we need to trigger the hooks starting only from its `parent` group.
        parent&.execute_hooks(data, :subgroup_hooks) # remove safe navigation with https://gitlab.com/gitlab-org/gitlab/-/issues/508611
      end
    end

    def custom_project_templates_group_allowed
      return if custom_project_templates_group_id.blank?
      return if children.exists?(id: custom_project_templates_group_id)

      errors.add(:custom_project_templates_group_id, 'has to be a subgroup of the group')
    end

    def billed_user_ids_excluding_guests
      strong_memoize(:billed_user_ids_excluding_guests) do
        ::Namespaces::BilledUsersFinder.new(self, exclude_guests: true).execute
      end
    end

    def billed_user_ids_including_guests
      strong_memoize(:billed_user_ids_including_guests) do
        ::Namespaces::BilledUsersFinder.new(self).execute
      end
    end

    def invited_or_shared_group_members(groups, exclude_guests: false)
      non_guests_scope = if ::Feature.enabled?(:assign_custom_roles_to_group_links_saas, self)
                           ::GroupMember.with_elevated_guests
                         else
                           ::GroupMember.non_guests
                         end

      guests_scope = exclude_guests ? non_guests_scope : ::GroupMember.all

      ::GroupMember.active_without_invites_and_requests
        .with_source_id(groups.self_and_ancestors)
        .merge(guests_scope)
    end

    def members_with_elevating_guest_member_role(groups)
      ::GroupMember.active_without_invites_and_requests
        .with_source_id(groups.self_and_ancestors)
        .merge(::GroupMember.elevated_guests)
    end

    def users_without_bots(members, merge_condition: ::User.all)
      ::User.id_in(members.select(:user_id)).without_bots.merge(merge_condition)
            .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/417464')
    end

    def projects_for_group_and_its_subgroups_without_deleted
      ::Project.for_group_and_its_subgroups(self).non_archived.without_deleted
    end

    override :safe_read_repository_read_only_column
    def safe_read_repository_read_only_column
      ::NamespaceSetting.where(namespace: self).pick(:repository_read_only)
    end

    override :update_repository_read_only_column
    def update_repository_read_only_column(value)
      settings = namespace_settings || create_namespace_settings

      settings.update_column(:repository_read_only, value)
    end
  end
end
