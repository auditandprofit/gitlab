# frozen_string_literal: true

module EE
  module Packages
    module PackageFile
      extend ActiveSupport::Concern

      EE_SEARCHABLE_ATTRIBUTES = %i[file_name].freeze

      prepended do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel
        include ::Geo::VerificationStateDefinition
        include ::Gitlab::SQL::Pattern

        with_replicator ::Geo::PackageFileReplicator
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        # Search for a list of package_files based on the query given in `query`.
        #
        # @param [String] query term that will search over package_file :file_name
        #
        # @return [ActiveRecord::Relation<Packages::PackageFile>] a collection of package files
        def search(query)
          return all if query.empty?

          fuzzy_search(query, EE_SEARCHABLE_ATTRIBUTES).limit(500)
        end

        override :selective_sync_scope
        def selective_sync_scope(node, **_params)
          return all unless node.selective_sync?

          joins(:package)
            .where(packages_packages: { project_id: ::Project.selective_sync_scope(node).select(:id) })
        end
      end
    end
  end
end
