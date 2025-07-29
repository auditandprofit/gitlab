# frozen_string_literal: true

module EE
  module Gitlab
    module Checks
      module Security
        module PolicyCheck
          PUSH_ERROR_MESSAGE = "Push is blocked by settings overridden by a security policy"
          FORCE_PUSH_ERROR_MESSAGE = "Force push is blocked by settings overridden by a security policy"
          LOG_MESSAGE = "Checking if scan result policies apply to branch..."

          def validate!
            return unless project.licensed_feature_available?(:security_orchestration_policies)

            logger.log_timed(LOG_MESSAGE) do
              break unless branch_name_affected_by_policy?
              break if policies_bypass_applied?

              if force_push?
                raise ::Gitlab::GitAccess::ForbiddenError, FORCE_PUSH_ERROR_MESSAGE
              elsif !matching_merge_request?
                raise ::Gitlab::GitAccess::ForbiddenError, PUSH_ERROR_MESSAGE
              end
            end
          end

          private

          def branch_name_affected_by_policy?
            affected_branches = ::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService
              .new(project: project).execute

            branch_name.in? affected_branches
          end

          def policies_bypass_applied?
            return false if ::Feature.disabled?(:security_policies_bypass_options_tokens_accounts, project)

            ::Security::ScanResultPolicies::PushBypassChecker.new(
              project: project, user_access: user_access, branch_name: branch_name
            ).check_bypass!
          end

          def force_push?
            ::Gitlab::Checks::ForcePush.force_push?(project, oldrev, newrev)
          end

          def matching_merge_request?
            ::Gitlab::Checks::MatchingMergeRequest.new(newrev, branch_name, project).match?
          end
        end
      end
    end
  end
end
