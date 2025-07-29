# frozen_string_literal: true

module Search
  module Elastic
    module Aggregations
      AGGREGATION_LIMIT = 500

      class << self
        def by_label_ids(query_hash:, max_size: AGGREGATION_LIMIT)
          query_hash.merge(
            size: 0,
            aggs: {
              'labels' => {
                terms: {
                  field: 'label_ids',
                  size: max_size
                }
              }
            }
          )
        end
      end
    end
  end
end
