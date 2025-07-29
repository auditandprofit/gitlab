# frozen_string_literal: true

module EE
  module BatchLoaders # rubocop:disable Gitlab/BoundedContexts -- Needed for override, will be removed after epics migration to work items
    module AwardEmojiVotesBatchLoader
      extend ActiveSupport::Concern

      class_methods do
        def load_votes_for(object, vote_type, awardable_class: nil)
          return super unless use_unified_batch_loading_for?(object)

          sync_awardable_class = object.sync_object&.class&.base_class&.name
          awardable_class ||= object.class.name

          batch_object = [object.id, object&.sync_object&.id]
          batch_key = "#{object.class.base_class.name}-#{vote_type}"

          BatchLoader::GraphQL.for(batch_object).batch(key: batch_key) do |ids, loader, _args|
            counts_for_object = votes_for_collection(ids.flat_map(&:first), awardable_class, vote_type)
            counts_for_sync_object = votes_for_collection(ids.flat_map(&:second), sync_awardable_class, vote_type)

            ids.each do |ids_pair|
              counts = counts_for_object[ids_pair[0]]&.count.to_i
              sync_counts = counts_for_sync_object[ids_pair[1]]&.count.to_i
              loader.call(ids_pair, counts + sync_counts)
            end
          end
        end

        def use_unified_batch_loading_for?(object)
          object.issuing_parent.is_a?(::Group) && object.sync_object.present?
        end

        def votes_for_collection(ids, awardable_class, vote_type)
          ::AwardEmoji
            .votes_for_collection(ids, awardable_class)
            .named(vote_type)
            .index_by(&:awardable_id)
        end
      end
    end
  end
end
