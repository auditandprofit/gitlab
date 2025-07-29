# frozen_string_literal: true

module Ai
  class CodeSuggestionEvent < ApplicationRecord
    include EachBatch
    include BaseUsageEvent

    self.table_name = "ai_code_suggestion_events"
    self.clickhouse_table_name = "code_suggestion_events"

    populate_sharding_key(:organization_id) { Gitlab::Current::Organization.new(user: user).organization&.id }

    enum :event, {
      code_suggestions_requested: 1, # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
      code_suggestion_shown_in_ide: 2,
      code_suggestion_accepted_in_ide: 3,
      code_suggestion_rejected_in_ide: 4,
      code_suggestion_direct_access_token_refresh: 5 # old data https://gitlab.com/gitlab-org/gitlab/-/issues/462809
    }

    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :organization_id, presence: true

    # Uses IN operator optimization to increase query efficiency
    def self.for(resource)
      namespace_ids_scope =
        if resource.is_a?(Project)
          Namespace.where(id: resource.project_namespace_id).select(:id)
        else
          resource.all_projects.select(:project_namespace_id)
        end

      # We filter by "timestamp <= Time.current" to skip scanning table future partitions
      recent_events_scope = where(timestamp: ...Time.current).order(timestamp: :desc, id: :desc)

      # Finds events where the namespace_path ends with the given namespace ID
      # Example: "1/2/3" matches namespace_id 3
      array_mapping_scope =
        ->(id_expression) {
          where(Arel.sql("(substring(namespace_path FROM '([0-9]+)[^0-9]*$'))::bigint").eq(id_expression))
        }

      Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
        scope: recent_events_scope,
        array_scope: namespace_ids_scope,
        array_mapping_scope: array_mapping_scope,
        finder_query: ->(_, id_expression) { where(arel_table[:id].eq(id_expression)) }
      ).execute
    end

    def to_clickhouse_csv_row
      super.merge({
        unique_tracking_id: payload['unique_tracking_id'],
        suggestion_size: payload['suggestion_size'],
        language: payload['language'],
        branch_name: payload['branch_name']
      })
    end
  end
end
