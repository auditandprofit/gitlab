# frozen_string_literal: true

module Search
  module Elastic
    module Sorts
      class << self
        def sort_by(query_hash:, options:)
          sort_hash = build_sort(options[:doc_type], options[:order_by], options[:sort])
          query_hash.merge(sort: sort_hash)
        end

        private

        def build_sort(doc_type, order_by, sort)
          # Due to different uses of sort param we prefer order_by when
          # present
          sort_and_direction = ::Gitlab::Search::SortOptions.sort_and_direction(order_by, sort)
          if ::Gitlab::Search::SortOptions::DOC_TYPE_ONLY_SORT[sort_and_direction] &&
              ::Gitlab::Search::SortOptions::DOC_TYPE_ONLY_SORT[sort_and_direction].exclude?(doc_type)
            sort_and_direction = nil
          end

          case sort_and_direction
          when :created_at_asc
            { created_at: { order: 'asc' } }
          when :created_at_desc
            { created_at: { order: 'desc' } }
          when :updated_at_asc
            { updated_at: { order: 'asc' } }
          when :updated_at_desc
            { updated_at: { order: 'desc' } }
          when :popularity_asc
            { upvotes: { order: 'asc' } }
          when :popularity_desc
            { upvotes: { order: 'desc' } }
          else
            {}
          end
        end
      end
    end
  end
end
