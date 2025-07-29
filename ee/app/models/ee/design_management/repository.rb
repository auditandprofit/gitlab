# frozen_string_literal: true

module EE
  module DesignManagement
    module Repository
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel

        delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :design_management_repository_state)

        with_replicator Geo::DesignManagementRepositoryReplicator

        has_one :design_management_repository_state,
          autosave: false,
          inverse_of: :design_management_repository,
          class_name: 'Geo::DesignManagementRepositoryState',
          foreign_key: 'design_management_repository_id'

        scope :available_verifiables, -> { joins(:design_management_repository_state) }

        scope :checksummed, -> {
          joins(:design_management_repository_state)
            .where
              .not(design_management_repository_states: { verification_checksum: nil })
        }

        scope :not_checksummed, -> {
          joins(:design_management_repository_state)
            .where(design_management_repository_states: { verification_checksum: nil })
        }

        scope :with_verification_state, ->(state) {
          joins(:design_management_repository_state)
            .where(design_management_repository_states: { verification_state: verification_state_value(state) })
        }

        scope :project_id_in, ->(ids) { where(project_id: ids) }
      end

      def verification_state_object
        design_management_repository_state
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        # @return [ActiveRecord::Relation<DesignManagement::Repository>] scope
        #         observing selective sync settings of the given node
        override :selective_sync_scope
        def selective_sync_scope(node, **params)
          return all unless node.selective_sync?

          # The primary_key_in in replicables_for_current_secondary method is at most a range
          # of IDs with a maximum of 10_000 records between them.
          replicables = params.fetch(:replicables, none)
          replicables_project_ids = replicables.distinct.pluck(:project_id)
          selective_projects_ids = ::Project.selective_sync_scope(node).id_in(replicables_project_ids).pluck_primary_key

          project_id_in(selective_projects_ids)
        end

        override :verification_state_table_class
        def verification_state_table_class
          Geo::DesignManagementRepositoryState
        end
      end

      # Geo checks this method in FrameworkRepositorySyncService to avoid
      # snapshotting repositories using object pools
      def pool_repository
        nil
      end

      def design_management_repository_state
        super || build_design_management_repository_state
      end
    end
  end
end
