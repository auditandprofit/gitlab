# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class RuleScheduleService < BaseProjectService
      include ::Gitlab::Loggable

      def execute(schedule)
        return ServiceResponse.error(message: "No rules") unless rules = schedule&.policy&.fetch(:rules, nil)

        rule = rules[schedule.rule_index]

        return ServiceResponse.error(message: "No scheduled rules") unless schedule_rule?(rule)

        branches = branches_for(rule)
        actions = actions_for(schedule)

        schedule_scans_using_a_worker(branches, schedule) unless actions.blank?

        ServiceResponse.success
      end

      private

      def schedule_rule?(rule)
        rule.present? && rule[:type] == Security::ScanExecutionPolicy::RULE_TYPES[:schedule]
      end

      def actions_for(schedule)
        policy = schedule.policy
        return [] if policy.blank?

        policy[:actions]
      end

      def branches_for(rule)
        ::Security::SecurityOrchestrationPolicies::PolicyBranchesService
          .new(project: project)
          .scan_execution_branches([rule])
      end

      def schedule_scans_using_a_worker(branches, schedule)
        if schedule.time_window
          time_window = schedule.time_window

          branches.map do |branch|
            ::Security::ScanExecutionPolicies::CreatePipelineWorker.perform_in(Random.rand(time_window).seconds,
              project.id,
              current_user.id,
              schedule.id,
              branch)
          end
        else
          branches.map do |branch|
            ::Security::ScanExecutionPolicies::CreatePipelineWorker.perform_async(project.id,
              current_user.id,
              schedule.id,
              branch)
          end
        end
      end
    end
  end
end
