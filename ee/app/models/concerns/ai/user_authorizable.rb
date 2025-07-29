# frozen_string_literal: true

module Ai
  module UserAuthorizable
    extend ActiveSupport::Concern

    GROUP_WITH_AI_ENABLED_CACHE_PERIOD = 1.hour
    GROUP_WITH_AI_ENABLED_CACHE_KEY = 'group_with_ai_enabled'

    BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_KEY = 'billable_duo_pro_root_group_ids'
    BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_PERIOD = 10.minutes

    DUO_PRO_ADD_ON_CACHE_KEY = 'user-%{user_id}-code-suggestions-add-on-cache'
    # refers to add-ons listed in GitlabSubscriptions::AddOn::DUO_ADD_ONS
    DUO_ADD_ONS_CACHE_KEY = 'user-%{user_id}-duo-add-ons-cache'
    AMAZON_Q_FEATURES = [:duo_chat, :code_suggestions, :troubleshoot_job, :explain_vulnerability,
      :resolve_vulnerability, :summarize_comments].freeze

    Response = Struct.new(:allowed?, :namespace_ids, :enablement_type, :authorized_by_duo_core, keyword_init: true)

    included do
      def duo_available_namespace_ids
        cache_key = duo_addons_cache_key_formatted

        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          GitlabSubscriptions::UserAddOnAssignment.by_user(self).for_active_gitlab_duo_purchase
            .pluck('subscription_add_on_purchases.namespace_id') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's purchases
            .uniq
        end
      end

      def duo_addons_cache_key_formatted
        format(DUO_ADD_ONS_CACHE_KEY, user_id: id)
      end

      def duo_pro_cache_key_formatted
        self.class.duo_pro_cache_key_formatted(id)
      end

      def eligible_for_self_managed_gitlab_duo_pro?
        return false if gitlab_com_subscription?

        active? && !bot? && !ghost?
      end

      # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups
      def billable_gitlab_duo_pro_root_group_ids
        return unless gitlab_com_subscription?

        Rails.cache.fetch(
          ['users', id, BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_KEY],
          expires_in: BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_PERIOD
        ) do
          group_ids_from_project_authorizaton = Project.id_in(project_authorizations.non_guests.select(:project_id))
            .pluck(:namespace_id)
          group_ids_from_memberships = GroupMember.with_user(self).active.non_guests.pluck(:source_id)
          group_ids_from_linked_groups = GroupGroupLink.non_guests
          .where(shared_with_group_id: group_ids_from_memberships)
            .pluck(:shared_group_id)

          root_group_ids = Group.where(
            id: group_ids_from_project_authorizaton | group_ids_from_memberships | group_ids_from_linked_groups
          ).pluck(Arel.sql('traversal_ids[1]')).uniq

          banned_root_group_ids = ::Namespaces::NamespaceBan.where(user_id: id).pluck(:namespace_id)

          root_group_ids - banned_root_group_ids
        end
      end
      # rubocop: enable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups

      def any_group_with_ai_available?
        Rails.cache.fetch(
          ['users', id, GROUP_WITH_AI_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_ENABLED_CACHE_PERIOD
        ) do
          member_namespaces.namespace_settings_with_ai_features_enabled.with_ai_supported_plan.any?
        end
      end

      def allowed_to_use?(ai_feature, service_name: nil, licensed_feature: :ai_features)
        allowed_to_use(ai_feature, service_name: service_name, licensed_feature: licensed_feature).allowed?
      end

      def allowed_by_namespace_ids(...)
        allowed_to_use(...).namespace_ids
      end

      def allowed_to_use(ai_feature, service_name: nil, licensed_feature: :ai_features)
        amazon_q_response = check_amazon_q_feature(ai_feature)
        return amazon_q_response if amazon_q_response

        # Check if feature and service are valid and available
        feature_data = Gitlab::Llm::Utils::AiFeaturesCatalogue.search_by_name(ai_feature)
        return denied_response unless feature_data

        service = CloudConnector::AvailableServices.find_by_name(service_name || ai_feature)
        return denied_response if service.name == :missing_service

        # Access through Duo Pro and Duo Enterprise
        add_on_response = check_add_on_purchases(service)
        return add_on_response if add_on_response

        # Access through Duo Core
        duo_core_response = check_duo_core_features(service)
        return duo_core_response if duo_core_response

        # If the user doesn't have access through Duo add-ons
        # and the service isn't free, they don't have access
        return denied_response unless service_free_access?(service)

        check_free_access(feature_data, licensed_feature)
      end

      private

      def service_free_access?(service)
        service.cut_off_date.nil? || service.cut_off_date&.future?
      end

      def check_add_on_purchases(service)
        # NOTE: We are passing `nil` as the resource to avoid filtering by namespace.
        # This is _not_ a good use of this API, and we should separate filtering by namespace
        # from filtering by user seat assignments. While this works, it will actually join
        # all add-on purchases in all tenant namespaces, which is not ideal.
        purchases = GitlabSubscriptions::AddOnPurchase.for_active_add_ons(service.add_on_names, nil)
                                                      .assigned_to_user(self)
        return unless purchases.any?

        Response.new(
          allowed?: true,
          namespace_ids: purchases.uniq_namespace_ids,
          enablement_type: purchases.last.normalized_add_on_name,
          authorized_by_duo_core: false
        )
      end

      def check_duo_core_features(service)
        return unless active? && !bot?
        return unless service.add_on_names.include?("duo_core") && duo_core_add_on?

        if saas?
          groups = groups_with_duo_core_enabled
          return unless groups.any?

          Response.new(
            allowed?: true,
            namespace_ids: groups.ids,
            enablement_type: duo_core_add_on_purchase.normalized_add_on_name,
            authorized_by_duo_core: true
          )
        elsif ::Ai::Setting.instance.duo_core_features_enabled?
          Response.new(
            allowed?: true,
            namespace_ids: [],
            enablement_type: duo_core_add_on_purchase.normalized_add_on_name,
            authorized_by_duo_core: true
          )
        end
      end

      def check_free_access(feature_data, licensed_feature)
        if saas?
          check_saas_free_access(feature_data)
        else
          check_sm_free_access(licensed_feature)
        end
      end

      def check_saas_free_access(feature_data)
        seats = namespaces_allowed_in_com(feature_data[:maturity])

        if seats.any?
          Response.new(allowed?: true, namespace_ids: seats, enablement_type: 'tier', authorized_by_duo_core: false)
        else
          denied_response
        end
      end

      def check_sm_free_access(licensed_feature)
        Response.new(allowed?: licensed_to_use_in_sm?(licensed_feature), namespace_ids: [],
          authorized_by_duo_core: false)
      end

      def denied_response
        Response.new(allowed?: false, namespace_ids: [], authorized_by_duo_core: false)
      end

      def groups_with_duo_core_enabled
        Namespace.id_in(billable_gitlab_duo_pro_root_group_ids)
          .namespace_settings_with_duo_core_features_enabled
      end

      def duo_core_add_on?
        duo_core_add_on_purchase.present?
      end

      def duo_core_add_on_purchase
        @duo_core_add_on_purchase ||= GitlabSubscriptions::AddOnPurchase.for_duo_core.for_user(self).active.first
      end

      def check_amazon_q_feature(ai_feature)
        return unless ::Ai::AmazonQ.connected?
        return unless AMAZON_Q_FEATURES.include?(ai_feature)

        Response.new(
          allowed?: true,
          namespace_ids: [],
          enablement_type: 'duo_amazon_q',
          authorized_by_duo_core: false
        )
      end

      def namespaces_allowed_in_com(maturity)
        namespaces = member_namespaces.with_ai_supported_plan
        namespaces = namespaces.namespace_settings_with_ai_features_enabled if maturity != :ga
        namespaces.ids
      end

      def licensed_to_use_in_sm?(licensed_feature)
        License.feature_available?(licensed_feature)
      end

      def saas?
        Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end
    end

    class_methods do
      def clear_group_with_ai_available_cache(ids)
        cache_keys_ai_features = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_AI_ENABLED_CACHE_KEY] }
        cache_keys_billable_duo_pro_group_ids = Array.wrap(ids).map do |id|
          ["users", id, BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_KEY]
        end

        cache_keys = cache_keys_ai_features + cache_keys_billable_duo_pro_group_ids
        ::Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end

      def duo_pro_cache_key_formatted(user_id)
        format(DUO_PRO_ADD_ON_CACHE_KEY, user_id: user_id)
      end
    end
  end
end
