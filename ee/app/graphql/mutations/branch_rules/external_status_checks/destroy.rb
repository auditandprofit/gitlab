# frozen_string_literal: true

module Mutations
  module BranchRules
    module ExternalStatusChecks
      class Destroy < BaseMutation
        graphql_name 'BranchRuleExternalStatusCheckDestroy'
        description 'Destroy an external status check from a branch rule'

        authorize :update_branch_rule

        argument :id, ::Types::GlobalIDType[::MergeRequests::ExternalStatusCheck],
          required: true,
          description: 'Global ID of the external status check to destroy.'

        argument :branch_rule_id, ::Types::GlobalIDType[::Projects::BranchRule],
          required: true,
          description: 'Global ID of the branch rule.'

        def resolve(branch_rule_id:, **params)
          branch_rule = authorized_find!(id: branch_rule_id)

          params[:id] = external_status_check_id(params[:id])

          service_response = ::BranchRules::ExternalStatusChecks::DestroyService
                               .new(branch_rule, current_user, params.merge(skip_authorization: true))
                               .execute

          { errors: Array(service_response.payload[:errors]) }
        end

        private

        def external_status_check_id(external_status_check_id)
          ::GitlabSchema.parse_gid(external_status_check_id).model_id
        end
      end
    end
  end
end
