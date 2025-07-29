# frozen_string_literal: true

module API
  class GroupApprovalRules < ::API::Base
    include PaginationParams

    before { authenticate! }
    before { check_feature_availability }
    before { check_feature_flag }

    helpers ::API::Helpers::GroupApprovalRulesHelpers

    feature_category :security_policy_management

    params do
      requires :id, type: String, desc: 'The ID of a group'
    end
    resource :groups, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      segment ':id/approval_rules' do
        desc 'Get all group approval rules' do
          success EE::API::Entities::GroupApprovalRule
        end
        params do
          use :pagination
        end
        get do
          authorize_group_approval_rule!

          group_approval_rules = paginate(user_group.approval_rules)

          present group_approval_rules, with: EE::API::Entities::GroupApprovalRule
        end

        desc 'Create new group approval rule' do
          success EE::API::Entities::GroupApprovalRule
        end
        params do
          requires :name, type: String, desc: 'The name of the approval rule'
          requires :approvals_required, type: Integer, desc: 'The number of required approvals for this rule'
          use :group_approval_rule
        end
        post do
          create_group_approval_rule(present_with: EE::API::Entities::GroupApprovalRule)
        end

        params do
          optional :name, type: String, desc: 'The name of the approval rule'
          optional :approvals_required, type: Integer, desc: 'The number of required approvals for this rule'
          use :group_approval_rule
        end

        put ':approval_rule_id' do
          update_group_approval_rule(present_with: EE::API::Entities::GroupApprovalRule)
        end
      end
    end
  end
end
