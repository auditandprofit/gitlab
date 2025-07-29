# frozen_string_literal: true

module WorkItems
  module UnifiedAssociations
    module AwardEmoji
      extend ActiveSupport::Concern

      included do
        # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
        has_many :own_award_emoji, as: :awardable, inverse_of: :awardable, class_name: 'AwardEmoji', dependent: :destroy
        # rubocop:enable Cop/ActiveRecordDependent -- legacy usage

        has_many :award_emoji, -> {
          includes(:user).order(:id)
        }, as: :awardable, inverse_of: :awardable, dependent: :destroy do # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
          def find(*args)
            return super unless proxy_association.owner.unified_associations?
            return super if block_given?

            scope.find(*args)
          end

          def load_target
            return super unless proxy_association.owner.unified_associations?

            proxy_association.target = scope.to_a unless proxy_association.loaded?

            proxy_association.loaded!
            proxy_association.target
          end

          def scope
            return super unless proxy_association.owner.unified_associations?

            ::AwardEmoji.from_union(
              [
                proxy_association.owner.sync_object&.own_award_emoji || AwardEmoji.none,
                proxy_association.owner.own_award_emoji
              ],
              remove_duplicates: false
            ).preload(:user)
          end
        end

        # Ensures that award_emoji associated with Legacy epic are
        # also destroyed when work item is destroyed.
        # This is needed because when a work item is deleted its
        # associated legacy epic will be destroyed via database
        # FK DELETE CASCADE and skip ActiveRecord callbacks.
        after_destroy :destroy_legacy_epic_award_emoji
        def destroy_legacy_epic_award_emoji
          return unless sync_object

          sync_object.own_award_emoji.delete_all # delete_all can be used to skip AR callbacks
        end
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        # Used to batch load unified award emoji on GraphQL
        def grouped_union_of_award_emojis(objects_relation, sync_objects_relation)
          ::AwardEmoji.from_union(
            ::AwardEmoji.where(awardable: objects_relation),
            ::AwardEmoji.where(awardable: sync_objects_relation),
            remove_duplicates: false
          ).preload(union_preloads).group_by { |emoji| [emoji.awardable_id, emoji.awardable_type] }
        end

        def union_preloads
          { awardable: [:work_item_type, :namespace, :group, :author] }
        end

        override :awarded
        def awarded(user, opts = {})
          return super unless apply_unified_emoji_association?

          inner_query = inner_filter_query(user, opts)

          inner_query =
            if self == Epic
              opts[:base_class_name] = 'Issue'
              opts[:awardable_id_column] = Epic.arel_table[:issue_id]
              inner_query.exists.or(inner_filter_query(user, opts).exists)
            else
              epics = ::Epic.arel_table
              emojis = ::AwardEmoji.arel_table
              issues = ::Issue.arel_table
              join_clause = emojis[:awardable_id].eq(epics[:id])
              opts[:awardable_id_column] = epics[:id]
              opts[:base_class_name] = 'Epic'

              inner_query
                .exists
                .or(
                  inner_filter_query(user, opts)
                  .join(epics).on(join_clause)
                  .where(issues[:id].eq(epics[:issue_id]))
                  .exists
                )
            end

          where(inner_query)
        end

        override :not_awarded
        def not_awarded(user, opts = {})
          return super unless apply_unified_emoji_association?

          inner_query = inner_filter_query(user, opts)

          inner_query =
            if self == Epic
              opts[:base_class_name] = 'Issue'
              opts[:awardable_id_column] = Epic.arel_table[:issue_id]
              inner_query.exists.not.and(inner_filter_query(user, opts).exists.not)
            else
              epics = ::Epic.arel_table
              emojis = ::AwardEmoji.arel_table
              issues = ::Issue.arel_table
              join_clause = emojis[:awardable_id].eq(epics[:id])
              opts[:awardable_id_column] = epics[:id]
              opts[:base_class_name] = 'Epic'

              inner_query
                .exists.not
                .and(
                  inner_filter_query(user, opts)
                  .join(epics).on(join_clause)
                  .where(issues[:id].eq(epics[:issue_id]))
                  .exists.not
                )
            end

          where(inner_query)
        end

        def apply_unified_emoji_association?
          [WorkItem, Epic].include?(self)
        end
      end

      # Used to batch load unified award emoji on GraphQL
      def batch_load_emojis_for_collection
        return award_emoji unless unified_associations?

        ::BatchLoader::GraphQL.for(emoji_batch_object).batch(
          key: self.class.name,
          cache: false
        ) do |ids, loader, _|
          objects_relation = self.class.id_in(ids.map(&:first).flat_map(&:first))
          sync_objects_relation = sync_object&.class&.id_in(ids.map(&:second).flat_map(&:first))

          emojis =
            self.class.grouped_union_of_award_emojis(objects_relation, sync_objects_relation)

          ids.each do |ids_pair|
            loader.call(ids_pair, [emojis[ids_pair[0]], emojis[ids_pair[1]]].flatten.compact || [])
          end
        end
      end

      # Used to batch load unified award emoji on GraphQL
      def emoji_batch_object
        [
          [id, self.class.base_class.name],
          [sync_object&.id, sync_object&.class&.base_class&.name]
        ]
      end
    end
  end
end
