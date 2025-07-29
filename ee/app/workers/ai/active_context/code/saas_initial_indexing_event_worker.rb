# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class SaasInitialIndexingEventWorker
        include Gitlab::EventStore::Subscriber
        include Gitlab::Utils::StrongMemoize
        prepend ::Geo::SkipSecondary

        feature_category :global_search
        deduplicate :until_executed
        data_consistency :sticky
        urgency :low
        idempotent!
        defer_on_database_health_signal :gitlab_main,
          [:p_ai_active_context_code_enabled_namespaces, :gitlab_subscriptions, :subscription_add_on_purchases],
          10.minutes

        NAMESPACE_IDS = [9970].freeze # gitlab-org namespace

        def handle_event(_)
          return false unless ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
          return false unless ::Ai::ActiveContext::Collections::Code.indexing?

          process_in_batches!
        end

        private

        def process_in_batches!
          duo_licenses = GitlabSubscriptions::AddOnPurchase.active.non_trial.for_duo_core_pro_or_enterprise
          duo_licenses = duo_licenses.by_namespace(NAMESPACE_IDS)

          total_count = 0

          duo_licenses.each_batch do |batch|
            namespace_ids = batch.map(&:namespace_id)
            records_to_insert = collect_eligible_namespaces(namespace_ids)

            next if records_to_insert.empty?

            Ai::ActiveContext::Code::EnabledNamespace.insert_all(
              records_to_insert,
              unique_by: %w[connection_id namespace_id]
            )

            total_count += records_to_insert.size
          end

          log_extra_metadata_on_done(:enabled_namespaces_created, total_count)
        end

        def collect_eligible_namespaces(namespace_ids)
          return [] if namespace_ids.empty?

          eligible_namespace_ids = namespace_ids - existing_namespace_ids(namespace_ids)
          return [] if eligible_namespace_ids.empty?

          records = []
          namespaces_with_valid_subscriptions(eligible_namespace_ids).find_each do |subscription|
            namespace = subscription.namespace

            if namespace_has_duo_features_enabled?(namespace) && namespace.root?
              records << { namespace_id: namespace.id, connection_id: active_connection.id }
            end
          end

          records
        end

        def existing_namespace_ids(namespace_ids)
          active_connection.enabled_namespaces.namespace_id_in(namespace_ids).find_each.map(&:namespace_id)
        end

        def active_connection
          Ai::ActiveContext::Connection.active
        end
        strong_memoize_attr :active_connection

        def namespaces_with_valid_subscriptions(namespace_ids)
          GitlabSubscription
            .with_a_paid_hosted_plan
            .not_expired
            .namespace_id_in(namespace_ids)
            .with_namespace_settings
        end

        def namespace_has_duo_features_enabled?(namespace)
          namespace.duo_features_enabled && namespace.experiment_features_enabled
        end
      end
    end
  end
end
