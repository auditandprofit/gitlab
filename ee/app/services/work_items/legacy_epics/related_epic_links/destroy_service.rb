# frozen_string_literal: true

module WorkItems
  module LegacyEpics
    module RelatedEpicLinks
      INSUFFICIENT_PERMISSIONS_MESSAGE = /could not be removed due to insufficient permissions/

      class DestroyService
        def initialize(legacy_epic_link, legacy_epic, current_user, synced_epic: false)
          @legacy_epic_link = legacy_epic_link
          @legacy_epic = legacy_epic
          @current_user = current_user
          @synced_epic = synced_epic
        end

        def execute
          if use_work_item_service?
            item_ids = legacy_epic.work_item == work_item_source ? [work_item_target.id] : [work_item_source.id]

            ::WorkItems::RelatedWorkItemLinks::DestroyService
              .new(legacy_epic.work_item, current_user, { item_ids: item_ids })
              .execute
              .then { |result| transform_result(result) }
          else
            ::Epics::RelatedEpicLinks::DestroyService.new(legacy_epic_link, legacy_epic, current_user,
              synced_epic: synced_epic).execute
          end
        end

        private

        def use_work_item_service?
          return false unless legacy_epic.group.work_item_epics_ssot_enabled?

          WorkItems::RelatedWorkItemLink.for_source_and_target(work_item_source, work_item_target).present?
        end

        def work_item_source
          legacy_epic_link.source.work_item
        end

        def work_item_target
          legacy_epic_link.target.work_item
        end

        def transform_result(result)
          if result[:message].match?(INSUFFICIENT_PERMISSIONS_MESSAGE) || result[:http_status] == 403
            result[:message] = 'No Related Epic Link found'
            result[:http_status] = :not_found
          end

          result[:message] = 'Relation was removed' if result[:status] == :success

          result
        end

        attr_reader :legacy_epic_link, :legacy_epic, :current_user, :synced_epic
      end
    end
  end
end
