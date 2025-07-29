# frozen_string_literal: true

module ApprovalRules
  class BaseService < BaseContainerService
    def execute
      return ServiceResponse.error(message: %w[Prohibited], reason: :access_denied) unless can_edit?

      action
    end

    private

    def action
      raise 'Not implemented'
    end

    attr_reader :rule

    def can_edit?
      skip_authorization || can?(current_user, policy_action, rule)
    end

    def policy_action
      return :edit_group_approval_rule if group_container?

      :edit_approval_rule
    end

    def skip_authorization
      @skip_authorization ||= params&.delete(:skip_authorization)
    end

    def success
      ServiceResponse.success(payload: { rule: rule })
    end

    def error
      ServiceResponse.error(message: rule.errors.messages, payload: { rule: rule })
    end

    def merge_request_activity_counter
      Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter
    end
  end
end
