# frozen_string_literal: true

module WorkItems
  module LegacyEpics
    module RelatedEpicLinks
      class ListService
        include Gitlab::Utils::StrongMemoize

        def initialize(legacy_epics, group)
          @legacy_epics = legacy_epics
          @group = group
        end

        def execute
          if Feature.enabled?(:related_epic_links_from_work_items, group)
            WorkItems::RelatedWorkItemLink
              .for_source_or_target(legacy_epics.select(:issue_id))
              .for_source_type(epic_type)
              .for_target_type(epic_type)
              .preload_for_epic_link

          else
            Epic::RelatedEpicLink.for_source_or_target(legacy_epics)
          end
        end

        private

        def epic_type
          ::WorkItems::Type.default_by_type(:epic)
        end
        strong_memoize_attr :epic_type

        attr_reader :legacy_epics, :group
      end
    end
  end
end
