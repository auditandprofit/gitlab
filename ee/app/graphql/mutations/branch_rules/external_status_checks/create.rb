# frozen_string_literal: true

module Mutations
  module BranchRules
    module ExternalStatusChecks
      class Create < BaseMutation
        graphql_name 'BranchRuleExternalStatusCheckCreate'
        description 'Create a new external status check from a branch rule'

        authorize :update_branch_rule

        argument :branch_rule_id, ::Types::GlobalIDType[::Projects::BranchRule],
          required: true,
          description: 'Global ID of the branch rule to update.'

        argument :name, GraphQL::Types::String,
          required: true,
          description: 'Name of the external status check.'

        argument :external_url, GraphQL::Types::String,
          required: true,
          description: 'URL of external status check resource.'

        field :external_status_check,
          type: ::Types::BranchRules::ExternalStatusCheckType,
          null: true,
          description: 'New status check after mutation.'

        def resolve(branch_rule_id:, **params)
          branch_rule = authorized_find!(id: branch_rule_id)

          service_response = ::BranchRules::ExternalStatusChecks::CreateService
                               .new(branch_rule, current_user, params.merge(skip_authorization: true))
                               .execute

          status_check = service_response.payload[:rule]

          {
            external_status_check: (status_check if service_response.success?),
            errors: Array(service_response.payload[:errors])
          }
        end
      end
    end
  end
end
