# frozen_string_literal: true

module EE
  module Terraform
    module StateVersion
      extend ActiveSupport::Concern

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel
        include ::Geo::VerificationStateDefinition

        with_replicator ::Geo::TerraformStateVersionReplicator

        has_one :terraform_state_version_state,
          class_name: 'Geo::TerraformStateVersionState',
          foreign_key: :terraform_state_version_id,
          inverse_of: :terraform_state_version,
          autosave: false

        scope :project_id_in, ->(ids) { joins(:terraform_state).where('terraform_states.project_id': ids) }
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        # Search for a list of terraform_state_versions based on the query given in `query`.
        #
        # @param [String] query term that will search over :file attribute
        #
        # @return [ActiveRecord::Relation<Terraform::StateVersion>] a collection of terraform state versions
        def search(query)
          return all if query.empty?

          # The current file format for terraform state versions
          # uses the following structure: <version or uuid>.tfstate
          where(sanitize_sql_for_conditions({ file: "#{query}.tfstate" })).limit(1000)
        end

        override :selective_sync_scope
        def selective_sync_scope(node, **_params)
          return all unless node.selective_sync?

          project_id_in(::Project.selective_sync_scope(node))
        end
      end
    end
  end
end
