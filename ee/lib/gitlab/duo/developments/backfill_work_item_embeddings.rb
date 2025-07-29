# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class BackfillWorkItemEmbeddings
        def self.execute(project_id:)
          work_items_to_backfill = Project.find(project_id).work_items

          puts "Adding #{work_items_to_backfill.count} work item embeddings to the queue"

          work_items_to_backfill.each_batch do |batch|
            batch.each do |work_item|
              ::Search::Elastic::ProcessEmbeddingBookkeepingService.track_embedding!(work_item)
            end
          end

          while ::Search::Elastic::ProcessEmbeddingBookkeepingService.queue_size > 0
            puts "Queue size: #{::Search::Elastic::ProcessEmbeddingBookkeepingService.queue_size}"

            ::Search::Elastic::ProcessEmbeddingBookkeepingService.new.execute
          end

          puts "Finished processing the queue.
All work items for project (#{project_id}) now have embeddings."
        end
      end
    end
  end
end
