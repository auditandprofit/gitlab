# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Variables
        module Preloader
          module MergeRequest
            extend ::Gitlab::Utils::Override

            APPROVED_PRELOADS = [ # the `approved?` method when assigning `CI_MERGE_REQUEST_APPROVED`
              :approvals,
              :approved_by_users,
              {
                applicable_post_merge_approval_rules: [
                  :approved_approvers,
                  :group_users, :users,
                  { approval_project_rule: [:protected_branches, :group_users, :users] }
                ],
                approval_rules: [
                  :group_users, :users,
                  { approval_project_rule: [:protected_branches, :group_users, :users] }
                ],
                target_project: [
                  regular_or_any_approver_approval_rules: [:protected_branches, :group_users, :users]
                ],
                merge_request_diff: [
                  merge_request_diff_commits: [
                    :commit_author,
                    :committer
                  ]
                ]
              },
              :scan_result_policy_violations,
              :scan_result_policy_reads_through_violations,
              :running_scan_result_policy_violations,
              :scan_result_policy_reads_through_approval_rules
            ].freeze

            private

            override :preloads
            def preloads
              super + APPROVED_PRELOADS
            end
          end
        end
      end
    end
  end
end
