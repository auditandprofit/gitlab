# frozen_string_literal: true

module Security
  module Ingestion
    class AbstractTask
      def self.execute(...)
        new(...).execute
      end

      def initialize(pipeline, finding_maps, context = nil)
        @pipeline = pipeline
        @finding_maps = finding_maps
        @context = context
      end

      def execute
        raise "Implement the `execute` template method!"
      end

      private

      attr_reader :pipeline, :finding_maps, :context
    end
  end
end
