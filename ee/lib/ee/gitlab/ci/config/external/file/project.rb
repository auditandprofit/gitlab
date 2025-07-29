# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Config
        module External
          module File
            module Project
              extend ::Gitlab::Utils::Override

              private

              override :project_access_allowed?
              def project_access_allowed?(user, project)
                super || security_policy_management_project_access_allowed?(project)
              end

              def security_policy_management_project_access_allowed?(project)
                return false unless context.pipeline_policy_context&.policy_management_project_access_allowed?
                return false unless context.project.affected_by_security_policy_management_project?(project)

                ::Security::OrchestrationPolicyConfiguration.policy_management_project?(project) &&
                  project.project_setting.spp_repository_pipeline_access
              end
            end
          end
        end
      end
    end
  end
end
