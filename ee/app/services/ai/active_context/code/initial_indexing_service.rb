# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class InitialIndexingService
        include Gitlab::Loggable

        def self.execute(repository)
          new(repository).execute
        end

        def initialize(repository)
          @repository = repository
        end

        def execute
          update_repository_state!(:code_indexing_in_progress)

          last_indexed_id = nil

          run_indexer! do |indexed_id|
            enqueue_refs!([indexed_id])
            last_indexed_id = indexed_id
          end

          update_repository_state!(:embedding_indexing_in_progress)

          set_highest_enqueued_item!(last_indexed_id) if last_indexed_id
        rescue StandardError => e
          update_repository_state!(:failed, last_error: e.message)

          raise e
        end

        private

        attr_reader :repository

        def run_indexer!(&block)
          Indexer.run!(repository, &block)
        end

        def update_repository_state!(state, extra_params = {})
          repository.update!(state: state, **extra_params)

          if state == :failed
            log_error(state.to_s, last_error: extra_params[:last_error])
          else
            log_info(state.to_s)
          end
        end

        def enqueue_refs!(ids)
          ::Ai::ActiveContext::Collections::Code.track_refs!(hashes: ids, routing: repository.project_id)
        end

        def set_highest_enqueued_item!(item_id)
          repository.update!(
            initial_indexing_last_queued_item: item_id,
            indexed_at: Time.current
          )

          log_info(
            'set_highest_enqueued_item',
            initial_indexing_last_queued_item: item_id
          )
        end

        def log_info(message, extra_params = {})
          logger.info(build_log_payload(message, extra_params))
        end

        def log_error(message, extra_params = {})
          logger.error(build_log_payload(message, extra_params))
        end

        def build_log_payload(message, extra_params = {})
          params = {
            message: message,
            ai_active_context_code_repository_id: repository.id,
            project_id: repository.project_id
          }.merge(extra_params)

          build_structured_payload(**params)
        end

        def logger
          @logger ||= ::ActiveContext::Config.logger
        end
      end
    end
  end
end
