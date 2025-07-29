# frozen_string_literal: true

module Ai
  module ActiveContext
    class Collection < ApplicationRecord
      self.table_name = :ai_active_context_collections

      jsonb_accessor :metadata,
        include_ref_fields: :boolean,
        indexing_embedding_versions: [:integer, { array: true }],
        search_embedding_version: :integer,
        collection_class: :string

      belongs_to :connection, class_name: 'Ai::ActiveContext::Connection'

      validates :name, presence: true, length: { maximum: 255 }
      validates :name, uniqueness: { scope: :connection_id }
      validates :metadata, json_schema: { filename: 'ai_active_context_collection_metadata' }
      validates :number_of_partitions, presence: true, numericality: { greater_than_or_equal_to: 1, only_integer: true }
      validates :connection_id, presence: true

      def partition_for(routing_value)
        ::ActiveContext::Hash.consistent_hash(number_of_partitions, routing_value)
      end

      def update_metadata!(new_metadata)
        update!(metadata: metadata.merge(new_metadata))
      end
    end
  end
end
