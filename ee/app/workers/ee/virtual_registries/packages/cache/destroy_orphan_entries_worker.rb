# frozen_string_literal: true

module EE
  module VirtualRegistries
    module Packages
      module Cache
        module DestroyOrphanEntriesWorker
          extend ::Gitlab::Utils::Override

          override :perform_work
          def perform_work(model)
            next_item = next_item(model.constantize)

            return unless next_item

            next_item.destroy!
            log_metadata(next_item)
          rescue StandardError => exception
            next_item&.update_column(:status, :error) unless next_item&.destroyed?

            ::Gitlab::ErrorTracking.log_exception(
              exception,
              class: self.class.name
            )
          end

          override :remaining_work_count
          def remaining_work_count(model)
            super
            model.constantize.pending_destruction.limit(max_running_jobs + 1).count
          end

          private

          def next_item(klass)
            klass.transaction do
              next_item = klass.next_pending_destruction

              if next_item
                next_item.update_column(:status, :processing)
                log_cleanup_item(next_item)
              end

              next_item
            end
          end

          def log_metadata(cache_entry)
            log_extra_metadata_on_done(:cache_entry_id, cache_entry.id)
            log_extra_metadata_on_done(:group_id, cache_entry.group_id)
          end

          def log_cleanup_item(cache_entry)
            logger.info(structured_payload(cache_entry_id: cache_entry.id))
          end
        end
      end
    end
  end
end
