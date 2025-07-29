# frozen_string_literal: true

module Ai
  module ActiveContext
    class Connection < ApplicationRecord
      self.table_name = :ai_active_context_connections

      ADAPTERS_FOR_ADVANCED_SEARCH = [
        ::ActiveContext::Databases::Elasticsearch::Adapter,
        ::ActiveContext::Databases::Opensearch::Adapter
      ].freeze

      has_many :collections, class_name: 'Ai::ActiveContext::Collection'

      encrypts :options

      has_many :migrations, class_name: 'Ai::ActiveContext::Migration'
      has_many :enabled_namespaces, class_name: 'Ai::ActiveContext::Code::EnabledNamespace',
        inverse_of: :active_context_connection
      has_many :repositories, class_name: 'Ai::ActiveContext::Code::Repository', inverse_of: :active_context_connection

      validates :name, presence: true, length: { maximum: 255 }, uniqueness: true
      validates :adapter_class, presence: true, length: { maximum: 255 }
      validates :prefix, length: { maximum: 255 }, allow_nil: true
      validates :active, inclusion: { in: [true, false] }
      validates :options, presence: true
      validate :validate_options
      validates_uniqueness_of :active, conditions: -> { where(active: true) }, if: :active

      def self.active
        where(active: true).first
      end

      def activate!
        return true if active?

        self.class.transaction do
          self.class.active&.update!(active: false)
          update!(active: true)
        end
      end

      def options
        if use_advanced_search_config?
          ::Gitlab::CurrentSettings.elasticsearch_config
        else
          super
        end
      end

      def use_advanced_search_config?
        ADAPTERS_FOR_ADVANCED_SEARCH.include?(adapter_class&.safe_constantize) &&
          read_attribute(:options)['use_advanced_search_config'] == true
      end

      private

      def validate_options
        return if options.is_a?(Hash)

        errors.add(:options, 'must be a hash')
      end
    end
  end
end
