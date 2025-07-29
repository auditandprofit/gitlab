# frozen_string_literal: true

module Search
  module Zoekt
    class SearchResults
      include ActionView::Helpers::NumberHelper
      include Gitlab::Utils::StrongMemoize
      include Gitlab::Loggable

      ZOEKT_COUNT_LIMIT = 5_000
      DEFAULT_PER_PAGE = Gitlab::SearchResults::DEFAULT_PER_PAGE
      ZOEKT_TARGETS_CACHE_EXPIRES_IN = 10.minutes

      attr_accessor :file_count

      attr_reader :current_user, :query, :public_and_internal_projects, :order_by, :sort, :filters, :modes,
        :source, :projects, :node_id, :multi_match, :options

      def initialize(
        current_user, query, projects = nil, **options)
        @current_user = current_user
        @query = query
        @source = options[:source]&.to_sym
        @filters = options.fetch(:filters, {})
        @projects = filtered_projects(projects)
        @node_id = options[:node_id]
        @order_by = options[:order_by]
        @sort = options[:sort]
        @modes = options.fetch(:modes, {})
        @multi_match = MultiMatch.new(options[:chunk_count]) if options.fetch(:multi_match_enabled, false)
        @options = options

        return unless options[:search_level].present?

        raise 'Specifying search level is not supported. Pass group_id or project_id instead.'
      end

      def limit_project_ids
        @limit_project_ids ||= projects.pluck_primary_key
      end

      def objects(_scope = 'blobs', page: 1, per_page: DEFAULT_PER_PAGE, preload_method: nil)
        blobs, @file_count = blobs_and_file_count(page: page, per_page: per_page, preload_method: preload_method)
        blobs
      end

      def formatted_count(_scope = 'blobs')
        limited_counter_with_delimiter(blobs_count)
      end

      def blobs_count
        @blobs_count ||= blobs_and_file_count[0].total_count
      end

      # These aliases act as an adapter to the Gitlab::SearchResults
      # interface, which is mostly implemented by this class.
      alias_method :limited_blobs_count, :blobs_count

      def parse_zoekt_search_result(result, project)
        ref = project.default_branch_or_main

        if multi_match
          multi_match.blobs_for_project(result, project, ref)
        else
          path = result[:path]
          basename = File.join(File.dirname(path), File.basename(path, '.*'))
          content = result[:content]
          project_id = project.id

          ::Gitlab::Search::FoundBlob.new(
            path: path,
            basename: basename,
            ref: ref,
            startline: [result[:line] - 1, 0].max,
            highlight_line: result[:line],
            data: content,
            project: project,
            project_id: project_id
          )
        end
      end

      def aggregations(*)
        []
      end

      def highlight_map(*)
        {}
      end

      def failed?(*)
        error.present?
      end

      def error(*)
        error_message
      end

      private

      attr_reader :error_message

      def base_options
        {
          current_user: current_user,
          public_and_internal_projects: public_and_internal_projects,
          order_by: order_by,
          sort: sort,
          projects: projects,
          node_id: node_id
        }
      end

      def memoize_key(scope, page:, per_page:, count_only:)
        count_only ? :"#{scope}_results_count" : :"#{scope}_#{page}_#{per_page}"
      end

      def blobs_and_file_count(page: 1, per_page: DEFAULT_PER_PAGE, count_only: false, preload_method: nil)
        return Kaminari.paginate_array([]), 0 if empty_results_preflight_check?

        strong_memoize(memoize_key(:blobs_and_file_count, page: page, per_page: per_page, count_only: count_only)) do
          search_as_found_blob(query, Repository, page: (page || 1).to_i, per_page: per_page,
            preload_method: preload_method
          )
        end
      end

      def limited_counter_with_delimiter(count)
        if count.nil?
          number_with_delimiter(0)
        elsif count >= ZOEKT_COUNT_LIMIT
          "#{number_with_delimiter(ZOEKT_COUNT_LIMIT)}+"
        else
          number_with_delimiter(count)
        end
      end

      def search_as_found_blob(query, _repositories, page:, per_page:, preload_method:)
        zoekt_search_and_wrap(query, page: page,
          per_page: per_page,
          preload_method: preload_method) do |result, project|
          parse_zoekt_search_result(result, project)
        end
      end

      # Performs zoekt search and parses the response
      #
      # @param query [String] search query
      # @param per_page [Integer] how many documents per page
      # @param options [Hash] additional options
      # @param page_limit [Integer] maximum number of pages we parse
      # @return [Array<Hash, Integer>] the results and total count
      def zoekt_search(query, per_page:, page_limit:)
        response = ::Gitlab::Search::Zoekt::Client.search_zoekt_proxy(
          query,
          num: ZOEKT_COUNT_LIMIT,
          search_mode: search_mode,
          current_user: current_user,
          targets: use_traversal_id_queries? ? nil : zoekt_targets,
          **options
        )

        if response.failure?
          @blobs_count = 0
          @error_message = response.error_message
          return [{}, @blobs_count, 0]
        end

        total_count = response.match_count.clamp(0, ZOEKT_COUNT_LIMIT)

        results = zoekt_extract_result_pages(response, per_page: per_page, page_limit: page_limit)
        [results, total_count, response.file_count]
      rescue ::Search::Zoekt::Errors::ClientConnectionError => e
        @blobs_count = 0
        @error_message = e.message
        [{}, @blobs_count, 0]
      end

      # Extracts results from the Zoekt response
      #
      # @param response [Hash] JSON response converted to hash
      # @param per_page [Integer] how many documents per page
      # @param page_limit [Integer] maximum number of pages we parse
      # @return [Hash<Integer, Array<Hash>>] results hash with pages as keys (zero-based)
      def zoekt_extract_result_pages(response, per_page:, page_limit:)
        return multi_match.zoekt_extract_result_pages_multi_match(response, per_page, page_limit) if multi_match

        results = {}
        page = 0
        response.each_file do |file|
          project_id = file[:RepositoryID].to_i

          file[:LineMatches].each do |match|
            current_page = page / per_page
            break if current_page == page_limit

            results[current_page] ||= []
            results[current_page] << build_result(file, match, project_id)
            page += 1
          end

          break if page / per_page == page_limit
        end

        results
      end

      def build_result(file, match, project_id)
        {
          project_id: project_id,
          content: decode_content(match),
          line: match[:LineNumber],
          path: file[:FileName]
        }
      end

      def decode_content(match)
        [:Before, :Line, :After].filter_map do |part|
          Base64.decode64(match[part]) if match[part]
        end.join
      end

      def zoekt_search_and_wrap(query, per_page:, page: 1, preload_method: nil, &blk)
        zoekt_cache = ::Search::Zoekt::Cache.new(
          query,
          current_user: current_user,
          page: page,
          per_page: per_page,
          project_ids: limit_project_ids,
          max_per_page: DEFAULT_PER_PAGE * 2,
          search_mode: search_mode,
          multi_match: multi_match
        )

        search_results, total_count, file_count = zoekt_cache.fetch do |page_limit|
          zoekt_search(query, per_page: per_page, page_limit: page_limit)
        end

        items, total_count = yield_each_zoekt_search_result(
          search_results[page - 1],
          preload_method,
          total_count,
          &blk
        )

        offset = (page - 1) * per_page
        [Kaminari.paginate_array(items, total_count: total_count, limit: per_page, offset: offset), file_count]
      end

      def yield_each_zoekt_search_result(response, preload_method, total_count)
        return [[], total_count] if total_count == 0 || response.blank?

        project_ids = response.pluck(:project_id).uniq # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
        projects = Project.with_route.id_in(project_ids)
        projects = projects.public_send(preload_method) if preload_method # rubocop:disable GitlabSecurity/PublicSend -- Method calls are forwarded
        projects = projects.index_by(&:id)

        items = response.map do |result|
          project_id = result[:project_id]
          project = projects[project_id]

          if project.nil? || project.pending_delete?
            total_count -= multi_match ? result[:match_count_total] : 1

            next
          end

          yield(result, project)
        end

        # Remove results for deleted projects
        items.compact!

        [items, total_count]
      end

      def search_mode
        return :regex if modes[:regex].nil? && source == :api

        Gitlab::Utils.to_boolean(modes[:regex]) ? :regex : :exact
      end

      def filtered_projects(projects)
        return Project.none if projects.blank?
        return Project.all if projects == :any

        filtered_projects = projects.without_order
        filtered_projects = filtered_projects.non_archived unless filters[:include_archived]

        # default behavior is to exclude forks
        if filters[:exclude_forks].nil? || (filters[:exclude_forks] == true)
          filtered_projects = filtered_projects.not_a_fork
        end

        Project.filter_out_public_projects_with_unauthorized_private_repos(filtered_projects, current_user)
      end

      def zoekt_targets
        sha = OpenSSL::Digest.hexdigest('SHA256', limit_project_ids.sort.join(','))
        cache_key = [
          self.class.name,
          :zoekt_targets,
          current_user&.id,
          sha
        ]

        Rails.cache.fetch(cache_key, expires_in: ZOEKT_TARGETS_CACHE_EXPIRES_IN) do
          ::Search::Zoekt::RoutingService.execute(projects)
        end
      end

      def empty_results_preflight_check?
        return true if query.blank? || (!use_traversal_id_queries? && limit_project_ids.empty?)

        if node_id.nil? && search_level == :project
          project = Project.find_by_id(options[:project_id])

          # Trigger async indexing if repository exists and isn't empty
          unless project&.empty_repo?
            logger.info(build_structured_payload(
              message: 'zoekt repository is not found for this search',
              project_id: project&.id,
              query: query
            ))
            Search::Zoekt.index_async(project&.id)
          end

          return true
        end

        false
      end

      def use_traversal_id_queries?
        use_ast_search_payload? && Feature.enabled?(:zoekt_traversal_id_queries, current_user)
      end

      def use_ast_search_payload?
        Feature.enabled?(:zoekt_ast_search_payload, current_user)
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
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
    end
  end
end
