# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicyDiff
      class Diff
        attr_accessor :diff, :rules_diff

        def self.from_json(diff, rules_diff)
          diff ||= {}
          rules_diff ||= {}
          new.tap do |policy_diff|
            policy_diff.diff = diff.transform_values do |value|
              FieldDiff.new(from: value[:from], to: value[:to])
            end
            policy_diff.rules_diff = RulesDiff.from_json(rules_diff)
          end
        end

        def initialize
          @diff = {}
          @rules_diff = Security::SecurityOrchestrationPolicies::PolicyDiff::RulesDiff.new
        end

        delegate :add_created_rule, :add_updated_rule, :add_deleted_rule, to: :rules_diff

        def add_policy_field(field, from, to)
          diff[field] = Security::SecurityOrchestrationPolicies::PolicyDiff::FieldDiff.new(from: from, to: to)
        end

        def to_h
          {
            diff: diff.transform_values(&:to_h),
            rules_diff: rules_diff.to_h
          }
        end

        def any_changes?
          diff.present? || rules_diff.any_changes?
        end

        def needs_refresh?
          status_changed? || scope_changed? || schedules_changed? || rules_diff.any_changes?
        end

        def needs_rules_refresh?
          rules_diff.updated.any? || actions_changed? || fallback_behavior_changed?
        end

        def needs_complete_rules_refresh?
          return false unless actions_changed?

          approval_count_from = approval_actions_count(diff[:actions].from)
          approval_count_to = approval_actions_count(diff[:actions].to)

          approval_count_from != approval_count_to
        end

        def status_changed?
          diff.key?(:enabled)
        end

        def actions_changed?
          diff.key?(:actions)
        end

        def fallback_behavior_changed?
          diff.key?(:fallback_behavior)
        end

        def scope_changed?
          diff.key?(:policy_scope)
        end

        def content_changed?
          diff.key?(:content)
        end

        def schedules_changed?
          diff.key?(:schedules)
        end

        def content_project_changed?
          content_changed? &&
            diff[:content].from&.dig(:include, 0, :project) != diff[:content].to&.dig(:include, 0, :project)
        end

        private

        def approval_actions_count(actions)
          Array.wrap(actions).count { |action| action[:type] == 'require_approval' }
        end
      end
    end
  end
end
