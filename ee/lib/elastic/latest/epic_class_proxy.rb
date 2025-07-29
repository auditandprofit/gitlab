# frozen_string_literal: true

module Elastic
  module Latest
    class EpicClassProxy < ApplicationClassProxy
      include Elastic::Latest::Routing

      attr_reader :current_user, :options

      def elastic_search(query, options: {})
        @current_user = options[:current_user]
        @options = options

        query_hash = if options[:search_level].in?(%w[global group])
                       query_hash = basic_query_hash(%w[title^2 description], query, options)
                       query_hash = build_es_query(query_hash)
                       query_hash = apply_groups_filter(query_hash)
                       apply_sort(query_hash, options)
                     else
                       match_none
                     end

        search(query_hash, options)
      end

      def routing_options(options)
        return {} if options[:search_level] == 'global'

        root_namespace_id = group.root_ancestor.id

        { routing: "group_#{root_namespace_id}" }
      end

      def preload_indexing_data(relation)
        relation = relation.preload_for_indexing.each(&:lazy_labels)
        groups = relation.map(&:group)
        ::Namespaces::Preloaders::GroupRootAncestorPreloader.new(groups).execute

        relation
      end

      private

      def build_es_query(query_hash)
        return query_hash if current_user&.can_read_all_resources?

        query_hash[:query][:bool][:minimum_should_match] = 1
        query_hash[:query][:bool][:should] ||= []
        query_hash = add_filter(query_hash, :query, :bool, :should) do
          should_query_for_public_epics
        end

        return query_hash unless current_user

        query_hash = add_filter(query_hash, :query, :bool, :should) do
          should_query_for_private_epics_that_user_can_access
        end

        unless current_user.external?
          query_hash = add_filter(query_hash, :query, :bool, :should) do
            should_query_for_internal_epics
          end
        end

        add_filter(query_hash, :query, :bool, :should) do
          should_query_for_confidential_epics_that_user_can_access
        end
      end

      def apply_groups_filter(query_hash)
        return query_hash unless options[:search_level] == 'group'

        traversal_ids_ancestry_filter(query_hash, [group.elastic_namespace_ancestry],
          options)
      end

      def group
        group_ids = options[:group_ids]
        Group.find(group_ids.first)
      end

      def group_ids_user_can_read_epics(confidential: false)
        min_access_level = confidential ? ::Gitlab::Access::PLANNER : ::Gitlab::Access::GUEST
        finder_params = { min_access_level: min_access_level }
        if options[:search_level] == 'group'
          finder_params[:filter_group_ids] = group.self_and_descendants.pluck_primary_key
        end

        GroupsFinder.new(current_user, finder_params).execute.pluck("#{Group.table_name}.#{Group.primary_key}") # rubocop:disable CodeReuse/ActiveRecord -- we need pluck only the ids from the finder
      end

      def should_query_for_confidential_epics_that_user_can_access
        confidential_group_ids = group_ids_user_can_read_epics(confidential: true)
        return if confidential_group_ids.empty?

        query = { bool: { filter: [] } }

        add_filter(query, :bool, :filter) do
          { term: { confidential: { value: true, _name: "confidential:true" } } }
        end
        add_filter(query, :bool, :filter) do
          { terms: { group_id: confidential_group_ids, _name: "groups:can:read_confidential_epics" } }
        end
      end

      def should_query_for_private_epics_that_user_can_access
        non_confidential_group_ids = group_ids_user_can_read_epics
        return if non_confidential_group_ids.empty?

        query = { bool: { filter: [] } }
        add_filter(query, :bool, :filter) do
          { terms: { group_id: non_confidential_group_ids } }
        end

        add_filter(query, :bool, :filter) do
          { term: { visibility_level: { value: ::Gitlab::VisibilityLevel::PRIVATE,
                                        _name: "visibility_level:PRIVATE" } } }
        end

        add_filter(query, :bool, :filter) do
          { term: { confidential: { value: false, _name: "confidential:false" } } }
        end
      end

      def should_query_for_internal_epics
        query = { bool: { filter: [] } }
        query = add_filter(query, :bool, :filter) do
          { term: { visibility_level: { value: ::Gitlab::VisibilityLevel::INTERNAL,
                                        _name: "visibility_level:INTERNAL" } } }
        end
        add_filter(query, :bool, :filter) do
          { term: { confidential: { value: false, _name: "confidential:false" } } }
        end
      end

      def should_query_for_public_epics
        query = { bool: { filter: [] } }
        query = add_filter(query, :bool, :filter) do
          { term: { visibility_level: { value: ::Gitlab::VisibilityLevel::PUBLIC, _name: "visibility_level:PUBLIC" } } }
        end
        add_filter(query, :bool, :filter) do
          { term: { confidential: { value: false, _name: "confidential:false" } } }
        end
      end
    end
  end
end
