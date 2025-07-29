# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class Indexer
        include Gitlab::Utils::StrongMemoize
        include Gitlab::Loggable

        TIMEOUT = '30m'
        Error = Class.new(StandardError)

        def self.run!(active_context_repository, &block)
          new(active_context_repository).run(&block)
        end

        def initialize(active_context_repository)
          # `active_context_repository` refers to `Ai::ActiveContext::Code::Repository`
          # object used for tracking the state of embeddings indexing for a project
          # `project_repository` refers to the `Repository` object that points to the
          # actual git repository in Gitaly.
          @active_context_repository = active_context_repository
          @project = active_context_repository.project
          @project_repository = project.repository

          # get the from and to shas on initialize to ensure consistent values
          @from_sha = active_context_repository.last_commit
          @to_sha = project_repository.commit&.id
        end

        def run(&block)
          raise Error, 'Adapter not set' unless adapter
          raise Error, 'Commit not found' unless to_sha

          log_info('Start indexer')

          response_processor = IndexerResponseModifier.new(&block)
          stderr_output = []

          status = Gitlab::Popen.popen_with_streaming(command, nil, environment_variables) do |stream_type, line|
            case stream_type
            when :stdout
              response_processor.process_line(line)
            when :stderr
              stderr_output << line
            end
          end

          unless status == 0
            log_error(
              "Indexer failed",
              status: status,
              error_details: stderr_output.join
            )
            raise Error, "Indexer failed with status: #{status} and error: #{stderr_output.join}"
          end

          log_info('Indexer successful', status: status)

          active_context_repository.update!(last_commit: to_sha)
        end

        private

        attr_reader :active_context_repository, :project, :project_repository, :to_sha, :from_sha

        def command
          [
            Gitlab.config.elasticsearch.indexer_path,
            '-adapter', adapter.name,
            '-connection', ::Gitlab::Json.generate(connection),
            '-options', ::Gitlab::Json.generate(options)
          ]
        end

        def environment_variables
          { 'GITLAB_INDEXER_MODE' => 'chunk' }
        end

        def connection
          if Ai::ActiveContext::Connection::ADAPTERS_FOR_ADVANCED_SEARCH.include?(adapter.class)
            return elasticsearch_connection_options
          end

          adapter.connection.options
        end

        # gitlab-elasticsearch-indexer requires connection as { url: ['string1', 'string2'] }
        # This method converts various URL formats into the required string array format.
        def elasticsearch_connection_options
          urls = Array(adapter.connection.options.symbolize_keys[:url]).map do |url|
            url.is_a?(Hash) ? Addressable::URI.new(url.symbolize_keys).normalize.to_s : url
          end

          { url: urls }
        end

        def options
          {
            from_sha: from_sha,
            to_sha: to_sha,
            project_id: project.id,
            partition_name: collection_class.partition_name,
            partition_number: collection_class.partition_number(project.id),
            gitaly_config: gitaly_config,
            timeout: TIMEOUT
          }
        end

        def gitaly_config
          {
            storage: project.repository_storage,
            relative_path: project_repository.relative_path,
            project_path: project.full_path
          }.merge(Gitlab::GitalyClient.connection_data(project.repository_storage))
        end

        def collection_class
          ::Ai::ActiveContext::Collections::Code
        end

        def adapter
          ::ActiveContext.adapter
        end
        strong_memoize_attr :adapter

        def log_info(message, extra_params = {})
          logger.info(build_log_payload(message, extra_params))
        end

        def log_error(message, extra_params = {})
          logger.error(build_log_payload(message, extra_params))
        end

        def build_log_payload(message, extra_params = {})
          params = {
            message: message,
            ai_active_context_code_repository_id: active_context_repository.id,
            project_id: project.id,
            from_sha: from_sha,
            to_sha: to_sha
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
