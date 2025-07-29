# frozen_string_literal: true

module BulkImports
  module EpicObjectCreator
    extend ActiveSupport::Concern

    included do
      def save_relation_object(relation_object, relation_key, relation_definition, relation_index)
        return super unless %w[epics epic issues issue].include?(relation_key)

        if %w[issues issue].include?(relation_key)
          epic_from_association = relation_object.epic_issue&.epic
          relative_position = relation_object.epic_issue&.relative_position

          relation_object.epic_issue = nil
          super

          return handle_issue_with_epic_association(relation_object, epic_from_association, relative_position)

        end

        create_epic(relation_object) if relation_object.new_record?
      end

      def persist_relation(attributes)
        relation_object = super(**attributes)

        return relation_object if !relation_object || !relation_object.is_a?(::Epic) || relation_object.persisted?

        create_epic(relation_object)
      end

      private

      def create_epic(epic_object)
        # we need to handle epics slightly differently because Epics::CreateService accounts for creating the
        # respective epic work item as well as some other associations.
        ::WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService.new(
          group: epic_object.group, current_user: current_user, epic_object: epic_object
        ).execute
      end

      def handle_issue_with_epic_association(issue, epic, relative_position)
        return issue unless epic

        epic_work_item = epic.new_record? ? create_epic(epic)&.work_item : epic.work_item
        issue_as_work_item = WorkItem.find_by_id(issue.id)

        return unless issue_as_work_item && epic_work_item

        link = create_parent_link(epic_work_item, issue_as_work_item, relative_position)
        return issue unless link

        issue
      end

      def create_parent_link(parent_work_item, child_work_item, relative_position)
        # since we are working with imported items, we have to temporarily set this attribute on the child, so that
        # the Epics::Links::CreateService knows not to perform validation related to hierarchy.

        # Importing isn't set on the child work item anymore because we persisted it separately to handle the epic issue
        # relation first. More context on the discussion around work item hierarchy permissions vs legacy epics
        # can be found here https://gitlab.com/gitlab-org/gitlab/-/issues/505855
        child_work_item.importing = true
        result = ::WorkItems::ParentLinks::CreateService.new(
          parent_work_item,
          current_user,
          { target_issuable: child_work_item, relative_position: relative_position }
        ).execute

        child_work_item.importing = nil

        return unless result[:status] == :success

        result[:created_references]&.first
      end
    end
  end
end
