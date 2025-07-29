# frozen_string_literal: true

module WorkItems
  module UnifiedAssociations
    module NotesExtension
      def load_target
        return super unless proxy_association.owner.unified_associations?

        proxy_association.target = scope.to_a unless proxy_association.loaded?

        proxy_association.loaded!
        proxy_association.target
      end

      def scope
        Note.from_union(
          [
            proxy_association.owner.sync_object&.own_notes || Note.none,
            proxy_association.owner.own_notes
          ],
          remove_duplicates: false).preload(noteable: :sync_object)
      end

      def find(*args)
        return super unless proxy_association.owner.unified_associations?
        return super if block_given?

        scope.find(*args)
      end

      def authors_loaded?
        # We check first if we're loaded to not load unnecessarily.
        loaded? && to_a.all? { |note| note.association(:author).loaded? }
      end

      def award_emojis_loaded?
        # We check first if we're loaded to not load unnecessarily.
        loaded? && to_a.all? { |note| note.association(:award_emoji).loaded? }
      end

      def projects_loaded?
        # We check first if we're loaded to not load unnecessarily.
        loaded? && to_a.all? { |note| note.association(:project).loaded? }
      end

      def system_note_metadata_loaded?
        # We check first if we're loaded to not load unnecessarily.
        loaded? && to_a.all? { |note| note.association(:system_note_metadata).loaded? }
      end
    end
  end
end
