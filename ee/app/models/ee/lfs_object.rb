# frozen_string_literal: true

module EE
  # LFS Object EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `LfsObject` model
  module LfsObject
    extend ActiveSupport::Concern

    STORE_COLUMN = :file_store

    prepended do
      include ::Geo::ReplicableModel
      include ::Geo::VerifiableModel

      delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :lfs_object_state)

      with_replicator ::Geo::LfsObjectReplicator

      scope :project_id_in, ->(ids) { joins(:projects).merge(::Project.id_in(ids)) }

      has_one :lfs_object_state, autosave: false, inverse_of: :lfs_object, class_name: 'Geo::LfsObjectState'

      scope :with_verification_state, ->(state) { joins(:lfs_object_state).where(lfs_object_states: { verification_state: verification_state_value(state) }) }
      scope :checksummed, -> { joins(:lfs_object_state).where.not(lfs_object_states: { verification_checksum: nil }) }
      scope :not_checksummed, -> { joins(:lfs_object_state).where(lfs_object_states: { verification_checksum: nil }) }

      scope :available_verifiables, -> { joins(:lfs_object_state) }

      def verification_state_object
        lfs_object_state
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # Search for a list of lfs_objects based on the query given in `query`.
      #
      # @param [String] query term that will search over lfs_object :file attribute
      #
      # @return [ActiveRecord::Relation<LfsObject>] a collection of LFS objects
      def search(query)
        return all if query.empty?

        where(sanitize_sql_for_conditions({ file: query })).limit(1000)
      end

      # @param primary_key_in [Range, LfsObject] arg to pass to primary_key_in scope
      # @return [ActiveRecord::Relation<LfsObject>] everything that should be synced
      #         to this node, restricted by primary key
      override :replicables_for_current_secondary
      def replicables_for_current_secondary(primary_key_in)
        node = ::Gitlab::Geo.current_node

        replicables =
          available_replicables
            .merge(object_storage_scope(node))
            .primary_key_in(primary_key_in)

        replicables.merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
      end

      # @return [ActiveRecord::Relation<LfsObject>] scope observing selective
      #         sync settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **params)
        return all unless node.selective_sync?

        replicables = params.fetch(:replicables, none)

        lfs_object_projects =
          if params.key?(:primary_key_in)
            LfsObjectsProject.project_id_in(::Project.selective_sync_scope(node)).where(lfs_object_id: params[:primary_key_in])
          else
            LfsObjectsProject.project_id_in(::Project.selective_sync_scope(node))
          end

        replicables.where(id: lfs_object_projects.select(:lfs_object_id).distinct)
      end

      override :verification_state_table_class
      def verification_state_table_class
        Geo::LfsObjectState
      end
    end

    def lfs_object_state
      super || build_lfs_object_state
    end
  end
end
