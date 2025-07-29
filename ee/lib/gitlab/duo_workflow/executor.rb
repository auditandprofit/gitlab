# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Executor
      def self.executor_binary_url
        Gitlab.config.duo_workflow.executor_binary_url
      end

      def self.executor_binary_urls
        Gitlab.config.duo_workflow.executor_binary_urls.to_h
      end

      def self.version
        Gitlab.config.duo_workflow.executor_version
      end
    end
  end
end
