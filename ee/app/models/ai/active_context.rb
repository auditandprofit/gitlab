# frozen_string_literal: true

module Ai
  module ActiveContext
    class << self
      def paused?
        return false unless ::ActiveContext.indexing?
        return false unless ::ActiveContext.adapter.connection.use_advanced_search_config?

        Gitlab::CurrentSettings.elasticsearch_pause_indexing?
      end
    end
  end
end
