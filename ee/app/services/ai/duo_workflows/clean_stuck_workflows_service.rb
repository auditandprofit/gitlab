# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CleanStuckWorkflowsService
      include ::Services::ReturnServiceResponses

      EXPIRATION_IN_MINUTES = 10
      BATCH_LIMIT = 1000

      def execute
        scope = Ai::DuoWorkflows::Workflow.with_status(:created, :running)
                  .stale_since(EXPIRATION_IN_MINUTES.minutes.ago)
        iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: scope)

        iterator.each_batch(of: BATCH_LIMIT) do |workflows|
          workflows.to_a.each(&:drop)
        end

        success(:processed)
      end
    end
  end
end
