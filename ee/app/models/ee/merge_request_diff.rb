# frozen_string_literal: true

module EE
  module MergeRequestDiff
    extend ActiveSupport::Concern

    prepended do
      include ::Geo::ReplicableModel
      include ::Geo::VerifiableModel

      delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :merge_request_diff_detail)

      with_replicator ::Geo::MergeRequestDiffReplicator

      has_one :merge_request_diff_detail, autosave: false, inverse_of: :merge_request_diff

      scope :has_external_diffs, -> { with_files.where(stored_externally: true) }
      scope :project_id_in, ->(ids) { where(merge_request_id: ::MergeRequest.where(target_project_id: ids)) }
      scope :available_replicables, -> { has_external_diffs }
      scope :available_verifiables, -> { joins(:merge_request_diff_detail) }
      scope :with_verification_state, ->(state) { joins(:merge_request_diff_detail).where(merge_request_diff_details: { verification_state: verification_state_value(state) }) }
      scope :checksummed, -> { joins(:merge_request_diff_detail).where.not(merge_request_diff_details: { verification_checksum: nil }) }
      scope :not_checksummed, -> { joins(:merge_request_diff_detail).where(merge_request_diff_details: { verification_checksum: nil }) }

      def verification_state_object
        merge_request_diff_detail
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # Search for a list of merge_request_diffs based on the query given in `query`.
      #
      # @param [String] query term that will search over external_diff attribute
      #
      # @return [ActiveRecord::Relation<MergeRequestDiff>] a collection of merge request diffs
      def search(query)
        return all if query.empty?

        where(sanitize_sql_for_conditions({ external_diff: query })).limit(1000)
      end

      # @return [ActiveRecord::Relation<MergeRequestDiff>] scope observing selective
      #         sync settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **_params)
        return all unless node.selective_sync?

        project_id_in(::Project.selective_sync_scope(node))
      end

      override :verification_state_table_class
      def verification_state_table_class
        MergeRequestDiffDetail
      end
    end

    def merge_request_diff_detail
      super || build_merge_request_diff_detail
    end
  end
end
