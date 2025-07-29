# frozen_string_literal: true

module Search
  module Zoekt
    class SearchRequest
      def initialize(current_user:, query:, **options)
        @query = query
        @current_user = current_user
        @options = options
      end

      def as_json
        {
          version: 2,
          timeout: options.fetch(:timeout, '120s'),
          num_context_lines: options.fetch(:num_context_lines, 20),
          max_file_match_window: options.fetch(:max_file_match_window, 1000),
          max_file_match_results: options.fetch(:max_file_match_results, 5),
          max_line_match_window: options.fetch(:max_line_match_window, 500),
          max_line_match_results: options.fetch(:max_line_match_results, 10),
          max_line_match_results_per_file: options.fetch(:max_line_match_results_per_file, 3),
          forward_to: use_traversal_id_queries? ? build_node_queries : build_node_queries_from_targets
        }
      end

      private

      def build_node_queries
        builder_options = {
          current_user: current_user,
          search_level: search_level,
          group_id: options[:group_id],
          project_id: options[:project_id],
          filters: options[:filters]
        }

        nodes.map do |node|
          CodeQueryBuilder.build(query: query, options: builder_options).tap do |payload|
            payload[:endpoint] = node.search_base_url
          end
        end
      end

      def build_node_queries_from_targets
        raise ArgumentError, 'No targets specified for the search request' unless options[:targets].present?

        options[:targets].filter_map do |node_id, repo_ids|
          node = ::Search::Zoekt::Node.find_by_id(node_id)
          next if node.nil?

          CodeQueryBuilder.build(query: query, options: { repo_ids: repo_ids }).tap do |payload|
            payload[:endpoint] = node.search_base_url
          end
        end
      end

      def nodes
        @nodes ||= if search_level == :global
                     ::Search::Zoekt::Node.online
                   else
                     enabled_namespace = root_ancestor&.zoekt_enabled_namespace

                     if enabled_namespace.blank?
                       raise ArgumentError, "No enabled namespace found for root ancestor: #{root_ancestor.inspect}"
                     end

                     enabled_namespace.nodes.online.tap do |n|
                       if n.empty?
                         raise ArgumentError, "No online nodes found for namespace: #{enabled_namespace.inspect}"
                       end
                     end
                   end
      end

      def search_level
        @search_level ||= if options[:group_id].present?
                            :group
                          elsif options[:project_id].present?
                            :project
                          else
                            :global
                          end
      end

      def root_ancestor
        @root_ancestor ||= if search_level == :group
                             ::Group.find(options[:group_id]).root_ancestor
                           elsif search_level == :project
                             ::Project.find(options[:project_id]).root_ancestor
                           end
      end

      def use_traversal_id_queries?
        use_ast_search_payload? && Feature.enabled?(:zoekt_traversal_id_queries, current_user)
      end

      def use_ast_search_payload?
        Feature.enabled?(:zoekt_ast_search_payload, current_user)
      end

      attr_reader :query, :current_user, :options
    end
  end
end
