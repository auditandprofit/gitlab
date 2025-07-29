# frozen_string_literal: true

module Search
  module Elastic
    module Delete
      class ProjectWorkItemsService < BaseService
        private

        def index_name
          ::Search::Elastic::Types::WorkItem.index_name
        end

        def build_query
          project_id = options[:project_id]
          traversal_id = options[:traversal_id]
          if project_id.nil?
            Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
              ArgumentError.new('project_id is required')
            )
            return
          end

          filter_list = [{ term: { project_id: project_id } }]

          unless traversal_id.nil?
            filter_list << { bool: { must_not: { prefix: { traversal_ids: { value: traversal_id } } } } }
          end

          {
            query: {
              bool: {
                filter: filter_list
              }
            }
          }
        end
      end
    end
  end
end
