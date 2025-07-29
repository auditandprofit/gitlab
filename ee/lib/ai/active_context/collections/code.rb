# frozen_string_literal: true

module Ai
  module ActiveContext
    module Collections
      class Code
        include ::ActiveContext::Concerns::Collection

        # We have calculated an average about 500 tokens per chunk
        # Vertex AI API limits 20,000 tokens per request
        # Each embeddings generation request should have a batch size of:
        # 20,000 / 50 = 40
        # Details: https://gitlab.com/gitlab-org/gitlab/-/issues/551002#note_2595329124
        EMBEDDINGS_V1_BATCH_SIZE = 40

        MODELS = {
          1 => {
            field: :embeddings_v1,
            model: 'text-embedding-005',
            class: Ai::ActiveContext::Embeddings::Code::VertexText,
            batch_size: EMBEDDINGS_V1_BATCH_SIZE
          }
        }.freeze

        def self.indexing?
          ::ActiveContext.indexing? && Ai::ActiveContext::Migration.complete?('SetCodeIndexingVersions')
        end

        def self.collection_name
          'gitlab_active_context_code'
        end

        def self.queue
          Queues::Code
        end

        def self.reference_klass
          References::Code
        end

        def self.partition_name
          collection_record.name
        end

        def self.partition_number(project_id)
          collection_record.partition_for(project_id)
        end

        def self.routing(object)
          object[:routing]
        end

        def self.track_refs!(routing:, hashes:)
          hashes.each { |hash| track!({ id: hash, routing: routing }) }
        end

        def self.redact_unauthorized_results!(result)
          return result if result.user.nil?

          project_ids = result.pluck('project_id') # rubocop: disable CodeReuse/ActiveRecord -- this an enum `pluck` method, not ActiveRecord
          projects = Project.id_in(project_ids).index_by(&:id)

          result.group_by { |r| r['project_id'] }.each_with_object([]) do |(project_id, project_objects), permitted|
            project = projects[project_id]

            permitted.concat(project_objects) if project && Ability.allowed?(result.user, :read_code, project)
          end
        end
      end
    end
  end
end
