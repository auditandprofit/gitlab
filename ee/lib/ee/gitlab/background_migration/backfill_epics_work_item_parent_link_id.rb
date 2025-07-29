# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillEpicsWorkItemParentLinkId
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class Epics < ApplicationRecord
          self.table_name = 'epics'
          self.inheritance_column = :_type_disabled
        end

        class WorkItemParentLinks < ApplicationRecord
          self.table_name = 'work_item_parent_links'
          self.inheritance_column = :_type_disabled
        end

        prepended do
          operation_name :backfill_epics_work_item_parent_link_id
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            # borrowed backfill work item parent link logic directly from
            # https://gitlab.com/gitlab-org/gitlab/-/blob/5aa2ea63fae6c7631d86a9708cbe1ad27e67a5dd/lib/gitlab/background_migration/backfill_work_item_hierarchy_for_epics.rb
            backfill_work_item_parent_links(sub_batch)
            update_epics_with_links(sub_batch)
          end
        end

        private

        def backfill_work_item_parent_links(sub_batch)
          Epics.transaction do
            # prevent an epic being updated while we sync its data to work_item_parent_links table.
            # Wrap the locking into a transaction so that locks are kept for the duration of transaction.
            parents_and_children_batch =
              sub_batch
                .joins("INNER JOIN epics parent_epics ON epics.parent_id = parent_epics.id")
                .joins("INNER JOIN issues ON parent_epics.issue_id = issues.id")
                .select(
                  <<-SQL
                    epics.issue_id AS child_id,
                    epics.relative_position,
                    parent_epics.issue_id AS parent_id,
                    issues.namespace_id as namespace_id
                  SQL
                ).lock!('FOR UPDATE').load

            parent_links = build_relationship(parents_and_children_batch)
            WorkItemParentLinks.upsert_all(parent_links, unique_by: :work_item_id) unless parent_links.blank?
          end
        end

        def build_relationship(parents_and_children_batch)
          # Use current time for timestamps because there is no way
          # to know when epics.parent_id "(created|updated)_at" was set
          timestamp = Time.current

          parents_and_children_batch.flat_map do |child_and_parent_data|
            {
              work_item_id: child_and_parent_data['child_id'],
              work_item_parent_id: child_and_parent_data['parent_id'],
              relative_position: child_and_parent_data['relative_position'],
              namespace_id: child_and_parent_data['namespace_id'],
              created_at: timestamp,
              updated_at: timestamp
            }
          end
        end

        def update_epics_with_links(sub_batch)
          sql = <<~SQL
          UPDATE epics
            SET work_item_parent_link_id = subquery.link_id
            FROM (
                SELECT
                    e.id as epic_id,
                    wpl.id as link_id
                FROM epics e
                JOIN work_item_parent_links wpl ON wpl.work_item_id = e.issue_id
                JOIN epics parent_epics ON parent_epics.id = e.parent_id
                WHERE wpl.work_item_parent_id = parent_epics.issue_id
                  AND e.id BETWEEN #{sub_batch.min.id} AND #{sub_batch.max.id}
                  AND e.work_item_parent_link_id IS NULL
                  AND e.parent_id IS NOT NULL
            ) subquery
            WHERE epics.id = subquery.epic_id
              AND epics.id BETWEEN #{sub_batch.min.id} AND #{sub_batch.max.id}
              AND epics.work_item_parent_link_id IS NULL
              AND epics.parent_id IS NOT NULL
          SQL

          ActiveRecord::Base.connection.execute(sql)
        end
      end
    end
  end
end
