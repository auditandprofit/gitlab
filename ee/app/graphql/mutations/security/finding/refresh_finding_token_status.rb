# frozen_string_literal: true

module Mutations
  module Security
    module Finding
      class RefreshFindingTokenStatus < BaseMutation
        graphql_name 'RefreshFindingTokenStatus'

        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorize :update_secret_detection_validity_checks_status

        field :finding_token_status,
          Types::Vulnerabilities::FindingTokenStatusType,
          null: true,
          description: 'Updated token status record for the given finding.'

        argument :vulnerability_id,
          ::Types::GlobalIDType[::Vulnerability],
          required: true,
          description: 'Global ID of the Vulnerability whose token status should be refreshed.'

        def resolve(vulnerability_id:)
          vuln = authorized_find!(id: vulnerability_id)

          raise_resource_not_available_error! unless vuln.project&.security_setting&.validity_checks_enabled?

          finding = vuln.finding
          return raise_resource_not_available_error! unless finding

          ::Security::SecretDetection::UpdateTokenStatusService
            .new
            .execute_for_finding(finding.id)

          token_status = finding.reset.finding_token_status
          unless token_status
            return { errors: [], finding_token_status: "Token status not found for finding #{finding.id}" }
          end

          { errors: [], finding_token_status: token_status }
        end
      end
    end
  end
end
