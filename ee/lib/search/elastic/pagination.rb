# frozen_string_literal: true

# This implementation assumes that there will always be
# a single sort property in the query already.
module Search
  module Elastic
    class Pagination
      include Search::Elastic::Concerns::FilterUtils

      attr_reader :query_hash

      def initialize(query_hash, default_tie_breaker_property = :id)
        @query_hash = query_hash.deep_dup
        @sort_property_value = nil
        @default_tie_breaker_property = default_tie_breaker_property
        @tie_breaker_property_value = nil
        @original_sort = query_hash[:sort]
      end

      def after(sort_property_value, tie_breaker_property_value)
        @sort_property_value = sort_property_value
        @tie_breaker_property_value = tie_breaker_property_value
        @is_after = true

        self
      end

      def before(sort_property_value, tie_breaker_property_value)
        @sort_property_value = sort_property_value
        @tie_breaker_property_value = tie_breaker_property_value

        self
      end

      def first(size)
        order

        query_hash[:size] = size

        paginate
      end

      def last(size)
        reverse_order

        query_hash[:size] = size

        paginate
      end

      def paginate
        return query_hash unless sort_property_value && tie_breaker_property_value

        add_filter(query_hash, :query, :bool, :filter) do
          {
            bool: {
              should: [
                {
                  range: {
                    sort_property => {
                      document_matching_operator(sort_direction) => sort_property_value
                    }
                  }
                },
                {
                  bool: {
                    must: [
                      {
                        term: {
                          sort_property => sort_property_value
                        }
                      },
                      {
                        range: {
                          tie_breaker_property => {
                            document_matching_operator(tie_breaker_sort_direction) => tie_breaker_property_value
                          }
                        }
                      }
                    ]
                  }
                }
              ]
            }
          }
        end
      end

      private

      attr_reader :sort_property_value,
        :default_tie_breaker_property,
        :tie_breaker_property_value,
        :original_sort,
        :is_after

      def sort_property
        @sort_property ||= original_sort.each_key.first
      end

      def sort_value
        @sort_value ||= original_sort.each_value.first
      end

      def sort_direction
        @sort_direction ||= sort_value[:order].to_sym
      end

      def tie_breaker_property
        @tie_breaker_property ||= original_sort.keys.second || default_tie_breaker_property
      end

      def tie_breaker_sort_value
        @tie_breaker_sort_value ||= original_sort.values.second || sort_value
      end

      def tie_breaker_sort_direction
        @tie_breaker_sort_direction ||= tie_breaker_sort_value[:order].to_sym
      end

      def order
        query_hash[:sort] = [
          { sort_property => sort_value.merge(order: sort_direction) },
          { tie_breaker_property => { order: tie_breaker_sort_direction } }
        ]
      end

      def reverse_order
        query_hash[:sort] = [
          { sort_property => sort_value.merge(order: reverse_sort_direction(sort_direction)) },
          { tie_breaker_property => { order: reverse_sort_direction(tie_breaker_sort_direction) } }
        ]
      end

      def document_matching_operator(direction)
        if direction == :asc
          is_after ? :gt : :lt
        else
          is_after ? :lt : :gt
        end
      end

      def reverse_sort_direction(direction)
        direction == :asc ? :desc : :asc
      end
    end
  end
end
