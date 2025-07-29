# frozen_string_literal: true

module Security
  module ScanExecutionPolicies
    class RuleScheduleWorker # rubocop:disable Scalability/IdempotentWorker
      include ApplicationWorker

      data_consistency :sticky

      feature_category :security_policy_management

      def perform(project_id, user_id, rule_schedule_id)
        project = Project.find_by_id(project_id)
        return unless project && !project.deletion_in_progress_or_scheduled_in_hierarchy_chain?

        user = User.find_by_id(user_id)
        return unless user

        schedule = Security::OrchestrationPolicyRuleSchedule.find_by_id(rule_schedule_id)
        return unless schedule

        return unless policy_applicable?(project, schedule.policy)

        Security::SecurityOrchestrationPolicies::RuleScheduleService
          .new(project: project, current_user: user)
          .execute(schedule)
      end

      private

      def policy_applicable?(project, policy)
        Security::SecurityOrchestrationPolicies::PolicyScopeChecker
          .new(project: project)
          .policy_applicable?(policy)
      end
    end
  end
end
