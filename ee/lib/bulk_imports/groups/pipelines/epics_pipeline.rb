# frozen_string_literal: true

module BulkImports
  module Groups
    module Pipelines
      class EpicsPipeline
        include NdjsonPipeline
        include ::BulkImports::EpicObjectCreator

        relation_name 'epics'

        extractor ::BulkImports::Common::Extractors::NdjsonExtractor, relation: relation

        def load(_context, data)
          epic, original_users_map = data

          return unless epic

          if context.importer_user_mapping_enabled?

            # BulkImports::EpicObjectCreator#create_epic creates a new Epic object instead of saving the one
            # built by RelationFactory and referenced in the original_users_map. This line updates the
            # original_users_map with the newly created Epic object.
            original_users_map[epic] = original_users_map.entries.find { |e| e.first.is_a?(Epic) }.last

            # With WorkItem, an issue is also created when the epic is created.
            # This line copies the epic original_users hash to the associated epic's issue
            # so placeholder references are also created for the issue.
            original_users_map[epic.issue] = original_users_map[epic] if epic.issue_id

            push_placeholder_references(original_users_map)
          end

          epic
        end
      end
    end
  end
end
