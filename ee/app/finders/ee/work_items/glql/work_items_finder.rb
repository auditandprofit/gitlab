# frozen_string_literal: true

# Used to filter Work Items collections by set of params in Elasticsearch
#
# Arguments:
#   current_user    - ActiveRecord instance representing the currently logged-in user
#   resource_parent - ActiveRecord instance representing the parent of the work items (either a Project or a Group)
#   context         - GraphQL context object (an instance of GraphQL::Query::Context) that holds per-request metadata,
#                     such as the HTTP request, current user, etc.
#   params:
#     state        - String with possible values of 'opened', 'closed', or 'all'
#     group_id     - ActiveRecord Group instance
#     project_id   - ActiveRecord Project instance
#     label_name   - Array of strings, can also accept wildcard values of "NONE" or "ANY"
#     sort         - Symbol with possible values of :created_desc or :created_asc
#     confidential - Boolean
#     author_username - String
#     milestone_title:       - Array of strings (cannot be simultaneously used with milestone_wildcard_id)
#     milestone_wildcard_id: - String with possible values of  'none', 'any', 'upcoming', 'started'
#                              (cannot be simultaneously used with milestone_title)
#     assignee_usernames:    - Array of strings
#     assignee_wildcard_id:  - String with possible values of  'none', 'any'
#     weight:                - String containing integer representing work item's weight
#     weight_wildcard_id:    - String with possible values of  'none', 'any'
#     issue_types:           - Array of strings (one of WorkItems::Type.base_types)
#     health_status_filter:  - String with possible values of 'on_track', 'needs_attention' and 'at_risk',
#                              can also accept wildcard values of "NONE" or "ANY"
#     not                    - Hash with keys that can be negated
#     or                     - Hash with keys that can be combined using OR logic
#
module EE
  module WorkItems
    module Glql
      module WorkItemsFinder
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        CONTROL_KEYS = [:sort, :include_ancestors, :include_descendants, :exclude_projects].freeze
        ALLOWED_ES_FILTERS = [
          :label_name, :group_id, :project_id, :state, :confidential, :author_username,
          :milestone_title, :milestone_wildcard_id, :assignee_usernames, :assignee_wildcard_id, :not, :or,
          :weight, :weight_wildcard_id, :issue_types, :health_status_filter
        ].freeze
        NOT_FILTERS = [:author_username, :milestone_title, :assignee_usernames, :label_name, :weight,
          :weight_wildcard_id, :health_status_filter, :milestone_wildcard_id].freeze
        OR_FILTERS = [:assignee_usernames, :label_names].freeze

        FILTER_NONE = 'none'
        FILTER_ANY = 'any'
        FILTER_MILESTONE_UPCOMING = 'upcoming'
        FILTER_MILESTONE_STARTED = 'started'

        GLQL_SOURCE = 'glql'

        attr_reader :current_user, :context, :params
        attr_accessor :resource_parent

        def execute
          result = search_service.search_results.objects('issues')

          ::WorkItem.glql_from_es_results(result)
        end

        override :use_elasticsearch_finder?
        def use_elasticsearch_finder?
          glql_request? &&
            url_param_enabled? &&
            use_elasticsearch? &&
            elasticsearch_enabled_for_namespace? &&
            elasticsearch_fields_supported?
        end

        # The logic for parent_param is copied from app/finders/issuable_finder.rb
        # Otherwise `find_all` fails in lib/gitlab/graphql/loaders/issuable_loader.rb
        def parent_param=(obj)
          self.resource_parent = obj
          params[parent_param] = resource_parent if resource_parent
        end

        def parent_param
          case resource_parent
          when Project
            :project_id
          when Group
            :group_id
          else
            raise "Unexpected parent: #{resource_parent.class}"
          end
        end

        private

        def search_service
          ::SearchService.new(current_user, search_params)
        end

        def search_params
          base_params.merge(scope_param)
        end

        def base_params
          {
            source: GLQL_SOURCE,
            search: '*',
            per_page: 100,
            sort: 'created_desc',
            state: params[:state],
            confidential: params[:confidential],
            work_item_type_ids: type_ids_from(params[:issue_types])
          }.merge(
            label_params,
            author_params,
            milestone_params,
            assignee_params,
            weight_params,
            health_status_params
          )
        end

        def label_params
          {
            label_names: label_names(params[:label_name]),
            not_label_names: label_names(params.dig(:not, :label_name)),
            or_label_names: label_names(params.dig(:or, :label_names)),
            none_label_names: none_labels?(params[:label_name]),
            any_label_names: any_labels?(params[:label_name])
          }
        end

        def author_params
          {
            author_username: params[:author_username],
            not_author_username: params.dig(:not, :author_username)
          }
        end

        def milestone_params
          {
            milestone_title: params[:milestone_title],
            not_milestone_title: params.dig(:not, :milestone_title),
            none_milestones: none_milestones?,
            any_milestones: any_milestones?,
            milestone_state_filters: milestone_state_filters
          }
        end

        def assignee_params
          {
            assignee_ids: assignee_ids(params[:assignee_usernames]),
            not_assignee_ids: assignee_ids(params.dig(:not, :assignee_usernames)),
            or_assignee_ids: assignee_ids(params.dig(:or, :assignee_usernames)),
            none_assignees: none_assignees?,
            any_assignees: any_assignees?
          }
        end

        def weight_params
          {
            # NOTE: We receive weight as a string on the API level, but ES stores weight as integer
            weight: params[:weight]&.to_i,
            not_weight: params.dig(:not, :weight)&.to_i,
            none_weight: none_weight?,
            any_weight: any_weight?
          }
        end

        def health_status_params
          # NOTE: health_status_filter receives different input types:
          # - Positive queries (health = "value") receive a string
          # - Negation queries (health != "value") receive an array
          # Converting everything to array for consistent handling and ES query structure
          status_filter = Array(params[:health_status_filter])
          not_status_filter = Array(params.dig(:not, :health_status_filter))

          {
            health_status: health_status(status_filter),
            not_health_status: health_status(not_status_filter),
            none_health_status: none_health_status?(status_filter),
            any_health_status: any_health_status?(status_filter)
          }
        end

        def scope_param
          if params[:project_id].present?
            { project_id: params[:project_id]&.id }
          else
            { group_id: params[:group_id]&.id }
          end
        end

        def any_milestones?
          params[:milestone_wildcard_id].to_s.downcase == FILTER_ANY
        end

        def none_milestones?
          params[:milestone_wildcard_id].to_s.downcase == FILTER_NONE
        end

        def type_ids_from(type_names)
          return unless type_names.present?

          Array(type_names).filter_map { |type| ::WorkItems::Type::BASE_TYPES.dig(type.to_sym, :id) }
        end

        def upcoming_milestone?
          params[:milestone_wildcard_id].to_s.downcase == FILTER_MILESTONE_UPCOMING
        end

        def started_milestone?
          params[:milestone_wildcard_id].to_s.downcase == FILTER_MILESTONE_STARTED
        end

        def not_upcoming_milestone?
          params.dig(:not, :milestone_wildcard_id).to_s.downcase == FILTER_MILESTONE_UPCOMING
        end

        def not_started_milestone?
          params.dig(:not, :milestone_wildcard_id).to_s.downcase == FILTER_MILESTONE_STARTED
        end

        def milestone_state_filters
          filters = []

          filters << :upcoming if upcoming_milestone?
          filters << :started if started_milestone?
          filters << :not_upcoming if not_upcoming_milestone?
          filters << :not_started if not_started_milestone?

          filters.presence
        end

        def use_elasticsearch?
          ::Gitlab::CurrentSettings.elasticsearch_search?
        end

        def elasticsearch_enabled_for_namespace?
          resource_parent.use_elasticsearch?
        end

        def glql_request?
          return unless request_params.present?

          request_params.fetch('operationName', nil) == 'GLQL'
        end

        def url_param_enabled?
          # Expected params are `useES=true` or `useES=false`
          # Defaults to `true` if no param is given
          # Otherwise fetches the value from the param when provided
          default = true
          use_es_value = request_referer_params.fetch('useES', [default]).first
          value = use_es_value.to_s.strip.downcase

          { 'true' => true, 'false' => false }.fetch(value, default)
        end

        def request_from_context
          context[:request]
        end

        def request_params
          request_from_context&.params
        end

        def request_referer
          request_from_context&.referer
        end

        def request_referer_params
          return {} unless request_referer.present?

          uri = URI.parse(request_referer)

          CGI.parse(uri.query.to_s)
        end

        def elasticsearch_fields_supported?
          allowed_main_filters? && allowed_not_filters? && allowed_or_filters?
        end

        def allowed_main_filters?
          filter_keys = params.keys - CONTROL_KEYS

          (filter_keys - ALLOWED_ES_FILTERS).empty?
        end

        def allowed_not_filters?
          return true unless params[:not].present?
          return false unless params[:not].is_a?(Hash)

          (params[:not].keys - NOT_FILTERS).empty?
        end

        def allowed_or_filters?
          return true unless params[:or].present?
          return false unless params[:or].is_a?(Hash)

          (params[:or].keys - OR_FILTERS).empty?
        end

        def none_assignees?
          params[:assignee_wildcard_id].to_s.downcase == FILTER_NONE
        end

        def any_assignees?
          params[:assignee_wildcard_id].to_s.downcase == FILTER_ANY
        end

        def assignee_ids(assignee_usernames)
          return unless assignee_usernames.present?

          ::User.by_username(assignee_usernames).pluck_primary_key
        end

        def any_labels?(names)
          Array(names).any? { |label| label.to_s.downcase == FILTER_ANY }
        end

        def none_labels?(names)
          Array(names).any? { |label| label.to_s.downcase == FILTER_NONE }
        end

        def label_names(names)
          return unless names.present?
          return if any_labels?(names) || none_labels?(names)

          names
        end

        def none_weight?
          params[:weight_wildcard_id].to_s.downcase == FILTER_NONE
        end

        def any_weight?
          params[:weight_wildcard_id].to_s.downcase == FILTER_ANY
        end

        def none_health_status?(statuses)
          statuses.any? { |status| status.to_s.downcase == FILTER_NONE }
        end

        def any_health_status?(statuses)
          statuses.any? { |status| status.to_s.downcase == FILTER_ANY }
        end

        def health_status(statuses)
          return unless statuses.present?
          return if none_health_status?(statuses) || any_health_status?(statuses)

          # NOTE: We receive health_status_filter as a 'string' on the API level,
          # but health_status is defined as a 'short' in ES mappings.
          statuses.filter_map { |status| ::WorkItem.health_statuses[status] }
        end
      end
    end
  end
end
