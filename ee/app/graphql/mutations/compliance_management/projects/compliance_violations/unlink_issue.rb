# frozen_string_literal: true

module Mutations
  module ComplianceManagement
    module Projects
      module ComplianceViolations
        class UnlinkIssue < BaseMutation
          graphql_name 'UnlinkProjectComplianceViolationIssue'

          include Mutations::ResolvesIssuable

          authorize :read_compliance_violations_report

          field :violation,
            ::Types::ComplianceManagement::Projects::ComplianceViolationType,
            null: true,
            description: 'Updated project compliance violation.'

          argument :violation_id, ::Types::GlobalIDType[::ComplianceManagement::Projects::ComplianceViolation],
            required: true,
            description: 'Global ID of the project compliance violation.'

          argument :project_path, GraphQL::Types::ID,
            required: true,
            description: 'Full path of the project the issue belongs to.'

          argument :issue_iid, GraphQL::Types::String,
            required: true,
            description: 'IID of the issue to be unlinked.'

          def resolve(violation_id:, project_path:, issue_iid:)
            violation = authorized_find!(id: violation_id)
            issue = find_issue(project_path, issue_iid)

            service_response = execute_unlink_service(violation, issue)

            if service_response.success?
              success_response(violation)
            else
              error_response(violation, service_response.message)
            end
          end

          private

          def find_issue(project_path, issue_iid)
            issue = resolve_issuable(type: :issue, parent_path: project_path, iid: issue_iid)

            raise_resource_not_available_error! if issue.blank?

            issue
          end

          def execute_unlink_service(violation, issue)
            ::ComplianceManagement::Projects::ComplianceViolations::UnlinkIssueService.new(
              current_user: current_user,
              violation: violation,
              issue: issue
            ).execute
          end

          def success_response(violation)
            {
              violation: violation,
              errors: []
            }
          end

          def error_response(violation, message)
            {
              violation: violation,
              errors: [message]
            }
          end
        end
      end
    end
  end
end
