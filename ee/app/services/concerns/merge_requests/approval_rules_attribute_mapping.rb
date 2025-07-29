# frozen_string_literal: true

module MergeRequests
  module ApprovalRulesAttributeMapping
    extend ActiveSupport::Concern

    def add_v2_approval_rules_attributes
      return unless params[:approval_rules_attributes]

      params[:v2_approval_rules_attributes] = params[:approval_rules_attributes].map do |rule|
        v2_rule = rule.dup.to_h
        v2_rule[:approver_user_ids] = rule[:user_ids]
        v2_rule[:approver_group_ids] = rule[:group_ids]
        v2_rule[:origin] = :merge_request
        v2_rule[:project_id] = project.id

        ActionController::Parameters.new(v2_rule).permit(
          :id,
          :_destroy,
          :rule_type,
          :name,
          :approvals_required,
          :origin,
          :project_id,
          approver_user_ids: [],
          approver_group_ids: []
        )
      end
    end

    def update_v1_approval_rule_ids(merge_request)
      return unless params[:v2_approval_rules_attributes].present? && params[:approval_rules_attributes].present?

      params[:approval_rules_attributes].each do |rule_attrs|
        next unless rule_attrs[:id].present?

        v2_rule = merge_request.v2_approval_rules.find(rule_attrs[:id])
        next unless v2_rule.present?

        v1_rule = merge_request.approval_rules.find_by_name(v2_rule.name)

        rule_attrs[:id] = v1_rule.id if v1_rule.present?
      end
    end
  end
end
