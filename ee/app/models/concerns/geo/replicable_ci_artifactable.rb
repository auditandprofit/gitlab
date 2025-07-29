# frozen_string_literal: true

module Geo
  module ReplicableCiArtifactable
    extend ActiveSupport::Concern

    class_methods do
      extend ::Gitlab::Utils::Override

      # @return [ActiveRecord::Relation<Ci::{PipelineArtifact|JobArtifact|SecureFile}>] scope
      #         observing selective sync settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **params)
        return all unless node.selective_sync?

        # The primary_key_in in replicables_for_current_secondary method is at most a range
        # of IDs with a maximum of 10_000 records between them. We can additionally reduce
        # the batch size to 1_000 just for pipeline artifacts and job artifacts if needed.
        replicables = params.fetch(:replicables, none)
        replicables_project_ids = replicables.distinct.pluck(:project_id) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- the query is already restricted to a range
        selective_projects_ids = ::Project.selective_sync_scope(node).id_in(replicables_project_ids).pluck_primary_key

        project_id_in(selective_projects_ids)
      end
    end
  end
end
