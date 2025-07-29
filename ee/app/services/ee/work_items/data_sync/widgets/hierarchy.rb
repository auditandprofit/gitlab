# frozen_string_literal: true

module EE
  module WorkItems
    module DataSync
      module Widgets
        module Hierarchy
          extend ::Gitlab::Utils::Override

          BATCH_SIZE = ::WorkItems::DataSync::Widgets::Base::BATCH_SIZE

          private

          override :relink_children_to_target_work_item
          def relink_children_to_target_work_item
            super

            # Every Epic Work Item has to have a legacy Epic record.
            source_legacy_epic = work_item.sync_object
            target_legacy_epic = target_work_item.sync_object
            return unless source_legacy_epic && target_legacy_epic

            # We need to handle legacy Epic children records upon Epic Work Item move.
            # Since we move legacy Epic to Work Item we will just "relink" child items to the new
            # parent legacy Epic.
            #
            # This will be removed once we remove legacy Epic dependencies,
            # see: https://gitlab.com/groups/gitlab-org/-/epics/13356
            epic_type = ::WorkItems::Type.default_by_type(:epic)
            return unless epic_type.id == work_item.work_item_type.id

            # handling child epics
            source_legacy_epic.children.each_batch(of: BATCH_SIZE) do |children|
              # we do not need to update `epics.work_item_parent_link_id`, because in
              # `super.relink_children_to_target_work_item` we did not create a new WorkItems::ParentLink record
              # we just changed the `work_item_parent_id` on the new target work item record.
              children.update_all(parent_id: target_legacy_epic.id)
            end

            # handling child issues
            source_legacy_epic.epic_issues.each_batch(of: BATCH_SIZE, column: :issue_id) do |epic_issue|
              # we do not need to update `epic_issues.work_item_parent_link_id`, because in
              # `super.relink_children_to_target_work_item` we did not create a new `WorkItems::ParentLink` record
              # we just changed the `work_item_parent_id` on the new target work item record.
              epic_issue.update_all(epic_id: target_legacy_epic.id)
            end
          end

          override :handle_parent
          def handle_parent
            super

            # Reload the parent_link association that was just created by the `super` call
            target_work_item.reload_parent_link

            copy_epic_parent
            copy_issue_parent
          end

          def copy_epic_parent
            # When an Epic Work Item is moved a corresponding legacy Epic record is being created. In order to keep
            # legacy Epic and Epic Work Item parent relationships in sync we need to update the new legacy Epic record
            # parent_id
            return unless target_work_item.sync_object.present?

            # ensure that the parent and the work_item_parent_link are being copied to the
            # targeted work item's legacy epic
            target_work_item.sync_object.update!(
              parent: work_item.sync_object.parent,
              work_item_parent_link: target_work_item.parent_link
            )
          end

          def copy_issue_parent
            # `epic_issue` will be present if the Issue has an epic as a parent. This is true for legacy Epic data.
            # This should not be needed once we finish legacy Epic cleanup in
            # Workstream 5: https://gitlab.com/groups/gitlab-org/-/epics/13356
            return unless work_item.epic_issue.present?

            epic_issue_attributes = work_item.epic_issue.attributes.except("id").tap do |attributes|
              attributes["issue_id"] = target_work_item.id
              attributes["namespace_id"] = target_work_item.namespace_id
              attributes["work_item_parent_link_id"] = target_work_item.parent_link.id
            end

            EpicIssue.create!(epic_issue_attributes)
          end
        end
      end
    end
  end
end
