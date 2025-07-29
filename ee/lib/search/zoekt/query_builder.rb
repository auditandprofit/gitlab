# frozen_string_literal: true

module Search
  module Zoekt
    class QueryBuilder
      def self.build(...)
        new(...).build
      end

      def initialize(query:, options: {})
        @query = query
        # allow extra_options to overwrite base_options
        @options = ::Gitlab::Utils.deep_indifferent_access(options.merge(base_options.merge(extra_options)))
        @auth = Search::AuthorizationContext.new(current_user)
      end

      def build
        raise NotImplementedError
      end

      private

      attr_reader :query, :options, :auth

      def current_user
        options[:current_user]
      end

      def group_id
        @group_id ||= options[:group_id]
      end

      def project_id
        @project_id ||= options[:project_id]
      end

      def group_ids
        [group_id].compact
      end

      def project_ids
        [project_id].compact
      end

      def authorized_traversal_ids
        @authorized_traversal_ids ||= auth.get_traversal_ids_for_user(
          features: 'repository',
          group_ids: group_ids,
          project_ids: project_ids,
          search_level: options.fetch(:search_level)
        )
      end

      def authorized_project_ids
        @authorized_project_ids ||= auth.get_project_ids_for_user(
          features: 'repository',
          group_ids: group_ids,
          project_ids: project_ids,
          search_level: options.fetch(:search_level)
        )
      end

      def filters
        options[:filters] || {}
      end

      def base_options
        {
          features: 'repository'
        }
      end

      # Subclasses should override this method to provide additional options to builder
      def extra_options
        {}
      end
    end
  end
end
