# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module ResyncApprovalPolicies
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        DELAY_INTERVAL = 10.seconds

        prepended do
          operation_name :resync_approval_policies
          scope_to ->(relation) {
            relation
              .where("type = 0 AND enabled = false")
              .or(relation.where("type = 0 AND length(scope::text) > 2"))
          }
        end

        class SecurityPolicy < ::ApplicationRecord
          self.table_name = 'security_policies'
        end

        override :perform
        def perform
          delay = 0
          each_sub_batch do |sub_batch|
            policies = SecurityPolicy
              .id_in(sub_batch)
              .select(:security_orchestration_policy_configuration_id)
              .distinct

            policies.each do |policy|
              ::Security::PersistSecurityPoliciesWorker
                .perform_in(delay, policy.security_orchestration_policy_configuration_id)

              delay += DELAY_INTERVAL
            end
          end
        end
      end
    end
  end
end
