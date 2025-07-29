# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillEpicIssuesWorkItemParentLinkId
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class EpicIssues < ApplicationRecord
          self.table_name = 'epic_issues'
        end

        class WorkItemParentLinks < ApplicationRecord
          self.table_name = 'work_item_parent_links'
        end

        prepended do
          operation_name :backfill_epic_issues_work_item_parent_link_id
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            epic_issue_data = sub_batch.where(work_item_parent_link_id: nil)
              .pluck(:id, :epic_id, :issue_id, :namespace_id, :relative_position)

            next if epic_issue_data.empty?

            epic_ids = epic_issue_data.pluck(1).uniq
            next if epic_ids.empty?

            epics_by_id, parent_links = fetch_related_data(epic_ids, epic_issue_data)
            epic_issue_updates, missing_parent_links =
              epic_issue_updates_and_missing_parent_links(epic_issue_data, epics_by_id, parent_links)

            create_missing_parent_links(missing_parent_links) unless missing_parent_links.empty?
            update_epic_issues(epic_issue_updates) unless epic_issue_updates.empty?
          end
        end

        private

        def fetch_related_data(epic_ids, epic_issue_data)
          # Batch fetch all epics
          epics_by_id = ::Epic.where(id: epic_ids).index_by(&:id)

          # Batch fetch all parent links
          issue_ids = epic_issue_data.pluck(2).uniq
          epic_work_item_ids = epics_by_id.values.map(&:issue_id)

          return [epics_by_id, {}] if epic_work_item_ids.empty?

          parent_links = WorkItemParentLinks.where(
            work_item_id: issue_ids,
            work_item_parent_id: epic_work_item_ids
          ).index_by { |link| [link.work_item_id, link.work_item_parent_id] }

          [epics_by_id, parent_links]
        end

        def epic_issue_updates_and_missing_parent_links(epic_issue_data, epics_by_id, parent_links)
          epic_issue_updates = []
          missing_parent_links = []

          epic_issue_data.each do |id, epic_id, issue_id, namespace_id, relative_position|
            epic = epics_by_id[epic_id]
            next unless epic

            parent_link = parent_links[[issue_id, epic.issue_id]]

            if parent_link
              epic_issue_updates << {
                id: id,
                work_item_parent_link_id: parent_link.id
              }
            else
              missing_parent_links << {
                epic_issue_id: id,
                work_item_id: issue_id,
                work_item_parent_id: epic.issue_id,
                namespace_id: namespace_id,
                relative_position: relative_position
              }
            end
          end

          [epic_issue_updates, missing_parent_links]
        end

        def create_missing_parent_links(missing_parent_links)
          parent_links_to_create = missing_parent_links.map do |link|
            {
              work_item_id: link[:work_item_id],
              work_item_parent_id: link[:work_item_parent_id],
              namespace_id: link[:namespace_id],
              relative_position: link[:relative_position]
            }
          end

          created_links = WorkItemParentLinks.insert_all(parent_links_to_create,
            returning: [:id, :work_item_id, :work_item_parent_id])

          parent_link_mapping = created_links.to_h do |link|
            [[link['work_item_id'], link['work_item_parent_id']], link['id']]
          end

          updates_for_new_links = missing_parent_links.filter_map do |link|
            {
              id: link[:epic_issue_id],
              work_item_parent_link_id: parent_link_mapping[[link[:work_item_id], link[:work_item_parent_id]]]
            }
          end

          update_epic_issues(updates_for_new_links) unless updates_for_new_links.empty?
        end

        def update_epic_issues(updates)
          return if updates.empty?

          update_cases = updates.map do |update|
            "WHEN #{update[:id]} THEN #{update[:work_item_parent_link_id]}"
          end.join(' ')

          ids = updates.pluck(:id)

          EpicIssues.connection.execute(<<~SQL)
            UPDATE epic_issues#{' '}
            SET work_item_parent_link_id = CASE id
              #{update_cases}
            END
            WHERE id IN (#{ids.join(',')})
          SQL
        end
      end
    end
  end
end
