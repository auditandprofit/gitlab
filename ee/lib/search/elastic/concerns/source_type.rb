# frozen_string_literal: true

module Search
  module Elastic
    module Concerns
      module SourceType
        TYPES = {
          glql: 'glql',
          search: 'search',
          api: 'api'
        }.freeze

        private

        def glql_query?(source)
          source == TYPES[:glql]
        end
      end
    end
  end
end
