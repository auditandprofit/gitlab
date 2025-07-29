# frozen_string_literal: true

module Search
  module Zoekt
    class RakeTaskExecutorService
      TASKS = %i[
        info
      ].freeze

      def initialize(logger:, options:)
        @logger = logger
        @options = options.with_indifferent_access
      end

      def execute(task)
        raise ArgumentError, "Unknown task: #{task}" unless TASKS.include?(task)
        raise NotImplementedError unless respond_to?(task, true)

        send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
      end

      private

      attr_reader :logger, :options

      def info
        InfoService.execute(logger: logger, options: options)
      end
    end
  end
end
