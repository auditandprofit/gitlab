# frozen_string_literal: true

module EE
  module BulkImports
    module Projects
      module Pipelines
        module IssuesPipeline
          include ::BulkImports::EpicObjectCreator

          def load(context, data)
            issue, _original_users_map = data

            return unless issue

            if issue.epic_issue.present?
              epic_from_association = issue.epic_issue.epic
              relative_position = issue.epic_issue.relative_position
              issue.epic_issue = nil
              super

              handle_issue_with_epic_association(issue, epic_from_association, relative_position)
            else
              super
            end
          end
        end
      end
    end
  end
end
