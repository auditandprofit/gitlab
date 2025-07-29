# frozen_string_literal: true

module Mutations
  module BranchRules
    module ExternalStatusChecks
      class Update < BaseMutation
        graphql_name 'BranchRuleExternalStatusCheckUpdate'
        description 'Update an external status check from a branch rule'

        authorize :update_branch_rule

        argument :id, ::Types::GlobalIDType[::MergeRequests::ExternalStatusCheck],
          as: :check_id,
          required: true,
          description: 'Global ID of the external status check to update.'

        argument :branch_rule_id, ::Types::GlobalIDType[::Projects::BranchRule],
          required: true,
          description: 'Global ID of the branch rule.'

        argument :name, GraphQL::Types::String,
          required: true,
          description: 'Name of the external status check.'

        argument :external_url, GraphQL::Types::String,
          required: true,
          description: 'External URL of the external status check.'

        field :external_status_check,
          type: ::Types::BranchRules::ExternalStatusCheckType,
          null: true,
          description: 'Updated external status check after mutation.'

        def resolve(branch_rule_id:, **params)
          branch_rule = authorized_find!(id: branch_rule_id)

          params[:check_id] = external_status_check_id(params[:check_id])

          service_response = ::BranchRules::ExternalStatusChecks::UpdateService.new(
            branch_rule,
            current_user,
            params.merge(skip_authorization: true)
          ).execute

          external_status_check = service_response.payload[:external_status_check]

          {
            external_status_check: (external_status_check if service_response.success?),
            errors: Array(service_response.payload[:errors])
          }
        end

        private

        def external_status_check_id(check_id)
          ::GitlabSchema.parse_gid(check_id).model_id
        end
      end
    end
  end
end
