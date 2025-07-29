# frozen_string_literal: true

module Mutations
  module ComplianceManagement
    module ComplianceFramework
      module ComplianceRequirementsControls
        class Destroy < BaseMutation
          graphql_name 'DestroyComplianceRequirementsControl'

          authorize :admin_compliance_framework

          argument :id, ::Types::GlobalIDType[
            ::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl
          ],
            required: true,
            description: 'Global ID of the compliance requirement control to destroy.'

          def resolve(id:)
            control = authorized_find!(id: id)

            result = ::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::DestroyService.new(
              control: control, current_user: current_user).execute

            { errors: result.success? ? [] : Array.wrap(result.message) }
          end
        end
      end
    end
  end
end
