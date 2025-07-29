# frozen_string_literal: true

module Ai
  class CodeSuggestionEventsFinder
    include Gitlab::Utils::StrongMemoize

    attr_reader :resource, :current_user

    # TODO - Replace with namespace_traversal_path filter
    # after https://gitlab.com/gitlab-org/gitlab/-/issues/531491
    CONTRIBUTORS_IDS_QUERY = <<~SQL
      SELECT DISTINCT author_id
      FROM contributions
      WHERE startsWith(path, {traversal_path:String})
      AND "contributions"."action" = 5
    SQL

    CONTRIBUTORS_IDS_NEW_QUERY = <<~SQL
      SELECT DISTINCT author_id
      FROM (
        SELECT
          argMax(author_id, "contributions_new".version) AS author_id,
          argMax(deleted, "contributions_new".version) AS deleted
        FROM contributions_new
        WHERE startsWith(path, {traversal_path:String})
        AND "contributions_new"."action" = 5
        GROUP BY id
      ) contributions_new
      WHERE deleted = false
    SQL
    private_constant :CONTRIBUTORS_IDS_QUERY

    def initialize(current_user, resource:)
      @current_user = current_user
      @resource = resource
    end

    def execute
      return ::Ai::CodeSuggestionEvent.none unless Ability.allowed?(current_user, :read_enterprise_ai_analytics,
        resource)

      if Feature.enabled?(:use_ai_events_namespace_path_filter, resource)
        ::Ai::CodeSuggestionEvent.for(resource)
      else
        # rubocop: disable CodeReuse/ActiveRecord -- will be replaced after namespace_path is populated at ai_code_suggestion_events
        ::Ai::CodeSuggestionEvent.where(user_id: contributors_ids)
        # rubocop: enable CodeReuse/ActiveRecord
      end
    end

    private

    # In this first iteration we consider users a contributor for a
    # group in two ways:
    # * When CH is available - All users that pushed to a project that belongs to the group at any time
    # * When CH is unavailable - Users that pushed to a project that belongs to the group in the last seven days
    # This is a temporary solution until `namespace_path` on `ai_code_suggestions` table is populated
    # and filtering by groups/projects implemented, after https://gitlab.com/gitlab-org/gitlab/-/issues/490601
    # we can move this logic to Ai::CodeSuggestionEvent model.
    def contributors_ids
      if ::Gitlab::ClickHouse.enabled_for_analytics?(resource)
        contributors_ids_from_ch
      else
        contributors_ids_from_postgresql
      end
    end

    # Users that pushed code in the last seven days
    # rubocop: disable CodeReuse/ActiveRecord -- Will be moved to model after refactoring on https://gitlab.com/gitlab-org/gitlab/-/issues/490601
    def contributors_ids_from_postgresql
      Event.pushed_action
        .where('created_at >= ?', 1.week.ago.beginning_of_day)
        .where(project_id: Project.for_group_and_its_subgroups(resource))
        .where(target_type: nil) # Filter for pushed events without targets to optimize index usage
        .select('DISTINCT author_id')
    end

    def fetch_contributions_from_new_table?
      Feature.enabled?(:fetch_contributions_data_from_new_tables, resource)
    end
    strong_memoize_attr :fetch_contributions_from_new_table?

    def contributors_ids_from_ch
      variables =
        {
          traversal_path: resource.traversal_path(with_organization: fetch_contributions_from_new_table?)
        }

      query =
        ClickHouse::Client::Query.new(raw_query: ch_contributors_ids_query, placeholders: variables)

      contributors = ClickHouse::Client.select(query, :main)

      # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- will be removed after namespace_path is populated at ai_code_suggestion_events
      contributors.pluck('author_id')
      # rubocop: enable Database/AvoidUsingPluckWithoutLimit
      # rubocop: enable CodeReuse/ActiveRecord
    end

    def ch_contributors_ids_query
      if fetch_contributions_from_new_table?
        CONTRIBUTORS_IDS_NEW_QUERY
      else
        CONTRIBUTORS_IDS_QUERY
      end
    end
  end
end
