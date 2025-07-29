# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PolicyBranchesService < BaseProjectService
      include Gitlab::Utils::StrongMemoize
      include Gitlab::InternalEventsTracking

      def scan_execution_branches(rules, source_branch = nil)
        track_branch_type_for_scan_execution_policies(rules)
        execute(:scan_execution, rules, source_branch)
      end

      def scan_result_branches(rules)
        execute(:scan_result, rules)
      end

      def skip_validation?(rule)
        rule[:branch_type].in?(%w[target_default target_protected])
      end

      private

      delegate :default_branch, to: :project

      def track_branch_type_for_scan_execution_policies(rules)
        rules.each do |rule|
          branch_type = rule[:branch_type].presence || 'custom'

          track_internal_event(
            'trigger_scan_execution_policy_by_branch_type',
            project: project,
            additional_properties: {
              label: branch_type # Branch type setting defined in policy rule
            })
        end
      end

      def execute(policy_type, rules, source_branch = nil)
        included_branches(policy_type, rules, source_branch) - excluded_branches(rules)
      end

      def included_branches(policy_type, rules, source_branch)
        return Set.new if rules.empty? || project.empty_repo?

        all_matched_branches = matched_branches(policy_type, rules, source_branch)

        return all_matched_branches if policy_type == :scan_execution

        # Scan result policies can only affect protected branches
        all_matched_branches & matched_protected_branches
      end

      def excluded_branches(rules)
        rules.reduce(Set.new) do |set, rule|
          set.merge(match_exceptions(rule))
        end
      end

      def match_exceptions(rule)
        exceptions = rule[:branch_exceptions]

        return [] unless exceptions&.any?

        exceptions_for_project = exceptions.filter_map do |exception|
          case exception
          when String then exception
          when Hash then if exception[:full_path].present? && exception[:full_path] == project.full_path
                           exception[:name]
                         end
          end
        end

        all_branches_matched_by(exceptions_for_project)
      end

      def matched_branches(policy_type, rules, source_branch)
        rules.reduce(Set.new) do |set, rule|
          set.merge(match_rule(policy_type, rule, source_branch))
        end
      end

      def match_rule(policy_type, rule, source_branch)
        return match_branch_types(rule[:branch_type], source_branch) if rule.key?(:branch_type)
        return match_branches(rule[:branches], policy_type) if rule.key?(:branches)

        []
      end

      def match_branch_types(branch_types, source_branch)
        case branch_types
        when "all" then all_project_branch_names
        when "protected" then matched_protected_branches
        when "default" then [default_branch].compact
        when "target_default" then source_branches_from_open_merge_requests(source_branch, [default_branch].compact)
        when "target_protected" then source_branches_from_open_merge_requests(source_branch, matched_protected_branches)
        else []
        end
      end

      def match_branches(branches, policy_type)
        return matched_protected_branches if policy_type == :scan_result && branches.empty?

        all_branches_matched_by(branches)
      end

      def matched_protected_branches
        all_branches_matched_by(all_protected_branch_names)
      end

      def all_branches_matched_by(patterns)
        patterns.flat_map do |pattern|
          RefMatcher.new(pattern).matching(all_branch_names)
        end
      end

      def source_branches_from_open_merge_requests(source_branch, target_branches)
        return [] if source_branch.blank? || target_branches.blank?

        project
          .merge_requests
          .opened
          .from_source_branches(source_branch)
          .by_target_branch(target_branches)
          .distinct_source_branches
      end

      # all_project_branch_names does not include group level protected_branches.
      # So we need to include all_protected_branch_names to check if the pattern
      # matches the group level protected_branches.
      def all_branch_names
        (all_project_branch_names + all_protected_branch_names).compact
      end

      def all_project_branch_names
        repository.branch_names
      end
      strong_memoize_attr :all_project_branch_names

      def all_protected_branch_names
        project.all_protected_branches.pluck(:name) # rubocop: disable CodeReuse/ActiveRecord
      end
      strong_memoize_attr :all_protected_branch_names
    end
  end
end
