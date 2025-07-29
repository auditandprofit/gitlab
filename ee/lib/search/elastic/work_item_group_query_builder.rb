# frozen_string_literal: true

module Search
  module Elastic
    class WorkItemGroupQueryBuilder < ::Search::Elastic::WorkItemQueryBuilder
      extend ::Gitlab::Utils::Override

      private

      override :get_confidentiality_filter
      def get_confidentiality_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_group_level_confidentiality(query_hash: query_hash, options: options)
      end

      override :get_authorization_filter
      def get_authorization_filter(query_hash:, options:)
        ::Search::Elastic::Filters.by_search_level_and_group_membership(query_hash: query_hash, options: options)
      end

      override :hybrid_work_item_search?
      def hybrid_work_item_search?
        false
      end

      override :extra_options
      def extra_options
        # reference for epic visibility: https://docs.gitlab.com/user/group/epics/manage_epics/#who-can-view-an-epic
        super.merge({
          features: nil,
          min_access_level_non_confidential: ::Gitlab::Access::GUEST,
          min_access_level_confidential: ::Gitlab::Access::PLANNER
        })
      end
    end
  end
end
