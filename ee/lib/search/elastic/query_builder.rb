# frozen_string_literal: true

module Search
  module Elastic
    class QueryBuilder
      include ::Elastic::Latest::QueryContext::Aware

      def self.build(...)
        new(...).build
      end

      def initialize(query:, options: {})
        @query = query
        # allow extra_options to overwrite base_options
        @options = options.merge(base_options.merge(extra_options))
      end

      def build
        raise NotImplementedError
      end

      private

      attr_reader :query, :options

      def base_options
        {
          project_id_field: :project_id,
          project_visibility_level_field: :visibility_level,
          no_join_project: true,
          source_fields: ['id']
        }
      end

      # Subclasses should override this method to provide additional options to builder
      def extra_options
        {}
      end
    end
  end
end
