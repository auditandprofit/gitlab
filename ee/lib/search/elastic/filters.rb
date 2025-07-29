# frozen_string_literal: true

module Search
  module Elastic
    module Filters
      include Search::Elastic::Filters::ConfidentialityFilters

      ALLOWED_SEARCH_LEVELS = %i[global group project].freeze
      DEFAULT_RELATED_SIZE = 100
      PROJECT_ID_FIELD = :project_id
      PROJECT_VISIBILITY_FIELD = :visibility_level
      TRAVERSAL_IDS_FIELD = :traversal_ids

      class << self
        include ::Elastic::Latest::QueryContext::Aware
        include Search::Elastic::Concerns::FilterUtils
        include Search::Elastic::Concerns::AuthorizationUtils
        include Search::Concerns::FeatureCustomAbilityMap

        def by_search_level_and_membership(query_hash:, options:)
          raise ArgumentError, 'search_level is required' unless options.key?(:search_level)

          user = options[:current_user]
          search_level = options[:search_level].to_sym
          raise ArgumentError, 'search_level invalid' unless ALLOWED_SEARCH_LEVELS.include?(search_level)

          return match_none_filter(query_hash) if cross_project_search_restricted_for_user?(user:, search_level:)

          query_hash = search_level_filter(query_hash: query_hash, options: options)

          add_filter(query_hash, :query, :bool, :filter) do
            build_membership_filter(options:).to_bool_query
          end
        end

        def by_source_branch(query_hash:, options:)
          source_branch = options[:source_branch]
          not_source_branch = options[:not_source_branch]

          return query_hash unless source_branch || not_source_branch

          context.name(:filters) do
            should = []
            if source_branch
              should << { term: { source_branch: { _name: context.name(:source_branch), value: source_branch } } }
            end

            if not_source_branch
              should << {
                bool: {
                  must_not: {
                    term: { source_branch: { _name: context.name(:not_source_branch), value: not_source_branch } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_target_branch(query_hash:, options:)
          target_branch = options[:target_branch]
          not_target_branch = options[:not_target_branch]

          return query_hash unless target_branch || not_target_branch

          context.name(:filters) do
            should = []
            if target_branch
              should << { term: { target_branch: { _name: context.name(:target_branch), value: target_branch } } }
            end

            if not_target_branch
              should << {
                bool: {
                  must_not: {
                    term: { target_branch: { _name: context.name(:not_target_branch), value: not_target_branch } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_author(query_hash:, options:)
          author_username = options[:author_username]
          not_author_username = options[:not_author_username]

          return query_hash unless author_username || not_author_username

          included_user = User.find_by_username(author_username)
          excluded_user = User.find_by_username(not_author_username)

          return query_hash unless included_user || excluded_user

          context.name(:filters) do
            should = []
            if included_user
              should << { term: { author_id: { _name: context.name(:author), value: included_user.id } } }
            end

            if excluded_user
              should << {
                bool: {
                  must_not: {
                    term: { author_id: { _name: context.name(:not_author), value: excluded_user.id } }
                  }
                }
              }
            end

            add_filter(query_hash, :query, :bool, :filter) do
              { bool: { should: should, minimum_should_match: 1 } }
            end
          end
        end

        def by_milestone(query_hash:, options:)
          # milestone_title filters and wildcard filters (any_milestones, none_milestones)
          # are mutually exclusive and should not be used together in the same query
          milestone_titles = options[:milestone_title]
          not_milestone_titles = options[:not_milestone_title]
          none_milestones = options[:none_milestones]
          any_milestones = options[:any_milestones]

          return query_hash unless milestone_titles || not_milestone_titles || none_milestones || any_milestones

          context.name(:filters) do
            if milestone_titles
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must: {
                      terms: {
                        _name: context.name(:milestone_title),
                        milestone_title: milestone_titles
                      }
                    }
                  }
                }
              end
            end

            if not_milestone_titles
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must_not: {
                      terms: {
                        _name: context.name(:not_milestone_title),
                        milestone_title: not_milestone_titles
                      }
                    }
                  }
                }
              end
            end

            if any_milestones
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:any_milestones),
                    must: { exists: { field: 'milestone_title' } }
                  }
                }
              end
            end

            if none_milestones
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:none_milestones),
                    must_not: { exists: { field: 'milestone_title' } }
                  }
                }
              end
            end
          end

          query_hash
        end

        def by_milestone_state(query_hash:, options:)
          # Unified milestone state filters holding an array of the following symbols
          # :upcoming, :started, :not_upcoming, :not_started
          milestone_state_filters = options[:milestone_state_filters]

          return query_hash unless milestone_state_filters

          context.name(:filters) do
            milestone_state_filters.each do |filter_type|
              base_query = {
                bool: {
                  _name: context.name("milestone_state_#{filter_type}"),
                  must: [
                    { term: { milestone_state: "active" } }
                  ]
                }
              }

              if filter_type == :upcoming || filter_type == :not_started
                # Both follow the same patterns: active milestones with start_date > now
                base_query[:bool][:must] << {
                  range: { milestone_start_date: { gt: "now/d" } }
                }
              end

              if filter_type == :started
                # Active milestones that have started but not finished
                # or that have started but have no due date
                # or that have no start date but due date is in the future
                base_query[:bool][:must].concat([
                  {
                    bool: {
                      should: [
                        { range: { milestone_start_date: { lte: "now/d" } } },
                        { bool: { must_not: { exists: { field: "milestone_start_date" } } } }
                      ]
                    }
                  },
                  {
                    bool: {
                      should: [
                        { range: { milestone_due_date: { gte: "now/d" } } },
                        { bool: { must_not: { exists: { field: "milestone_due_date" } } } }
                      ]
                    }
                  }
                ])

                base_query[:bool][:must_not] = {
                  bool: {
                    must: [
                      { bool: { must_not: { exists: { field: "milestone_start_date" } } } },
                      { bool: { must_not: { exists: { field: "milestone_due_date" } } } }
                    ]
                  }
                }
              end

              if filter_type == :not_upcoming
                # Active milestones that have already started (start_date <= now)
                base_query[:bool][:must] << {
                  range: { milestone_start_date: { lte: "now/d" } }
                }
              end

              add_filter(query_hash, :query, :bool, :filter) do
                base_query
              end
            end
          end

          query_hash
        end

        def by_assignees(query_hash:, options:)
          assignee_ids = options[:assignee_ids]
          not_assignee_ids = options[:not_assignee_ids]
          or_assignee_ids = options[:or_assignee_ids]
          none_assignees = options[:none_assignees]
          any_assignees = options[:any_assignees]

          unless assignee_ids || not_assignee_ids || or_assignee_ids || none_assignees || any_assignees
            return query_hash
          end

          context.name(:filters) do
            if assignee_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:assignee_ids),
                    must: assignee_ids.map do |assignee_id|
                      {
                        term: {
                          assignee_id: assignee_id
                        }
                      }
                    end
                  }
                }
              end
            end

            if not_assignee_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must_not: {
                      terms: {
                        _name: context.name(:not_assignee_ids),
                        assignee_id: not_assignee_ids
                      }
                    }
                  }
                }
              end
            end

            if or_assignee_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must: {
                      terms: {
                        _name: context.name(:or_assignee_ids),
                        assignee_id: or_assignee_ids
                      }
                    }
                  }
                }
              end
            end

            if none_assignees
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:none_assignees),
                    must_not: { exists: { field: 'assignee_id' } }
                  }
                }
              end
            end

            if any_assignees
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:any_assignees),
                    must: { exists: { field: 'assignee_id' } }
                  }
                }
              end
            end
          end

          query_hash
        end

        def by_weight(query_hash:, options:)
          weight = options[:weight]
          not_weight = options[:not_weight]
          none_weight = options[:none_weight]
          any_weight = options[:any_weight]

          return query_hash unless weight || not_weight || none_weight || any_weight

          context.name(:filters) do
            if weight
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  term: {
                    weight: {
                      _name: context.name(:weight),
                      value: weight
                    }
                  }
                }
              end
            end

            if not_weight
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must_not: {
                      term: {
                        weight: {
                          _name: context.name(:not_weight),
                          value: not_weight
                        }
                      }
                    }
                  }
                }
              end
            end

            if none_weight
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:none_weight),
                    must_not: { exists: { field: 'weight' } }
                  }
                }
              end
            end

            if any_weight
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:any_weight),
                    must: { exists: { field: 'weight' } }
                  }
                }
              end
            end
          end

          query_hash
        end

        def by_work_item_type_ids(query_hash:, options:)
          work_item_type_ids = options[:work_item_type_ids]
          not_work_item_type_ids = options[:not_work_item_type_ids]

          return query_hash unless work_item_type_ids || not_work_item_type_ids

          context.name(:filters) do
            if work_item_type_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must: {
                      terms: {
                        _name: context.name(:work_item_type_ids),
                        work_item_type_id: work_item_type_ids
                      }
                    }
                  }
                }
              end
            end

            if not_work_item_type_ids
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must_not: {
                      terms: {
                        _name: context.name(:not_work_item_type_ids),
                        work_item_type_id: not_work_item_type_ids
                      }
                    }
                  }
                }
              end
            end
          end
          query_hash
        end

        def by_not_hidden(query_hash:, options:)
          user = options[:current_user]
          return query_hash if user&.can_admin_all_resources?

          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              { term: { hidden: { _name: context.name(:not_hidden), value: false } } }
            end
          end
        end

        def by_health_status(query_hash:, options:)
          health_status = options[:health_status]
          not_health_status = options[:not_health_status]
          none_health_status = options[:none_health_status]
          any_health_status = options[:any_health_status]

          return query_hash unless health_status || not_health_status || none_health_status || any_health_status

          context.name(:filters) do
            if health_status
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must: {
                      terms: {
                        _name: context.name(:health_status),
                        health_status: health_status
                      }
                    }
                  }
                }
              end
            end

            if not_health_status
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    must_not: {
                      terms: {
                        _name: context.name(:not_health_status),
                        health_status: not_health_status
                      }
                    }
                  }
                }
              end
            end

            if none_health_status
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:none_health_status),
                    must_not: { exists: { field: 'health_status' } }
                  }
                }
              end
            end

            if any_health_status
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:any_health_status),
                    must: { exists: { field: 'health_status' } }
                  }
                }
              end
            end
          end

          query_hash
        end

        def by_state(query_hash:, options:)
          state = options[:state]
          return query_hash if state.blank? || state == 'all'
          return query_hash unless API::Helpers::SearchHelpers.search_states.include?(state)

          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              { match: { state: { _name: context.name(:state), query: state } } }
            end
          end
        end

        def by_archived(query_hash:, options:)
          raise ArgumentError, 'search_level is a required option' unless options.key?(:search_level)

          include_archived = !!options[:include_archived]
          search_level = options[:search_level].to_sym
          return query_hash if search_level == :project
          return query_hash if include_archived

          context.name(:filters) do
            archived_false_filter = { bool: { filter: { term: { archived: { value: false } } } } }
            archived_missing_filter = { bool: { must_not: { exists: { field: 'archived' } } } }
            exclude_archived_filter = { bool: { _name: context.name(:non_archived),
                                                should: [archived_false_filter, archived_missing_filter] } }

            add_filter(query_hash, :query, :bool, :filter) do
              exclude_archived_filter
            end
          end
        end

        # @deprecated - all new label filters should use by_label_names
        def by_label_ids(query_hash:, options:)
          return query_hash if options[:count_only] || options[:aggregation]

          return query_hash unless [options[:label_name]].flatten.any?

          label_names_hash = find_labels_by_name([options[:label_name]].flatten, options)
          return query_hash unless label_names_hash.any?

          must_query = { must: [] }
          context.name(:filters) do
            label_names_hash.each_value do |label_ids|
              must_query[:must] << {
                terms: {
                  _name: context.name(:label_ids),
                  label_ids: label_ids
                }
              }
            end
          end

          add_filter(query_hash, :query, :bool, :filter) do
            { bool: must_query }
          end
        end

        def by_label_names(query_hash:, options:)
          label_names = options[:label_names]
          not_label_names = options[:not_label_names]
          or_label_names = options[:or_label_names]
          none_label_names = options[:none_label_names]
          any_label_names = options[:any_label_names]

          unless label_names || not_label_names || or_label_names || none_label_names || any_label_names
            return query_hash
          end

          context.name(:filters) do
            if label_names
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:label_names),
                    must: build_label_queries(label_names)
                  }
                }
              end
            end

            if not_label_names
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:not_label_names),
                    must_not: build_label_queries(not_label_names)
                  }
                }
              end
            end

            if or_label_names
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:or_label_names),
                    should: build_label_queries(or_label_names),
                    minimum_should_match: 1
                  }
                }
              end
            end

            if none_label_names
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:none_label_names),
                    must_not: { exists: { field: 'label_names' } }
                  }
                }
              end
            end

            if any_label_names
              add_filter(query_hash, :query, :bool, :filter) do
                {
                  bool: {
                    _name: context.name(:any_label_names),
                    must: { exists: { field: 'label_names' } }
                  }
                }
              end
            end
          end

          query_hash
        end

        def by_knn(query_hash:, options:)
          return query_hash unless options[:embeddings]
          return query_hash unless options[:vectors_supported] == :elasticsearch

          filters = query_hash.dig(:query, :bool, :filter)

          query_hash.deep_merge(knn: { filter: filters })
        end

        def by_search_level_and_group_membership(query_hash:, options:)
          raise ArgumentError, 'search_level is required' unless options.key?(:search_level)

          user = options[:current_user]
          search_level = options[:search_level].to_sym
          raise ArgumentError, 'search_level invalid' unless ALLOWED_SEARCH_LEVELS.include?(search_level)

          return match_none_filter(query_hash) if cross_project_search_restricted_for_user?(user:, search_level:)

          query_hash = search_level_filter(query_hash: query_hash, options: options)
          return query_hash if user&.can_read_all_resources?

          add_filter(query_hash, :query, :bool, :filter) do
            context.name(:filters, :permissions, search_level) do
              permissions_filters = Search::Elastic::BoolExpr.new
              add_visibility_level_filter(user: user,
                visibility_level_field: :namespace_visibility_level,
                filter: permissions_filters)

              should = [{ bool: permissions_filters.to_h }]
              traversal_ids_prefix = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)

              authorized_traversal_ids = traversal_ids_for_user(user, options)
              unless authorized_traversal_ids.empty?
                membership_filters = Search::Elastic::BoolExpr.new

                add_filter(membership_filters, :must) do
                  { terms: {
                    _name: context.name(:namespace_visibility_level, :private),
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE]
                  } }
                end

                membership_filters.should += ancestry_filter(authorized_traversal_ids,
                  traversal_id_field: traversal_ids_prefix)

                should << membership_filters.to_bool_query
              end

              authorized_project_ancestry_namespace_ids = authorized_namespace_ids_for_project_group_ancestry(user)
              unless authorized_project_ancestry_namespace_ids.empty?
                membership_filters = Search::Elastic::BoolExpr.new

                add_filter(membership_filters, :must) do
                  { terms: {
                    _name: context.name(:namespace_visibility_level, :private),
                    namespace_visibility_level: [::Gitlab::VisibilityLevel::PRIVATE]
                  } }
                end

                add_filter(membership_filters, :must) do
                  { terms: {
                    _name: context.name(:project, :membership),
                    namespace_id: authorized_project_ancestry_namespace_ids
                  } }
                end

                should << membership_filters.to_bool_query
              end

              {
                bool: {
                  _name: context.name,
                  should: should,
                  minimum_should_match: 1
                }
              }
            end
          end
        end

        # @deprecated - use by_search_level_and_membership
        def by_project_authorization(query_hash:, options:)
          user = options[:current_user]
          project_ids = options[:project_ids]
          group_ids = options[:group_ids]
          use_traversal_ids = options.fetch(:authorization_use_traversal_ids)

          context.name(:filters) do
            if project_ids == :any || group_ids.blank? || !use_traversal_ids
              next project_ids_filter(query_hash, options)
            end

            namespaces = Namespace.find(authorized_namespace_ids(user, group_ids))

            next project_ids_filter(query_hash, options) if namespaces.blank?

            traversal_ids_filter(query_hash, namespaces, options)
          end
        end

        def by_type(query_hash:, options:)
          raise ArgumentError, 'by_type filter requires doc_type option' unless options.key?(:doc_type)

          doc_type = options[:doc_type]
          context.name(:filters) do
            add_filter(query_hash, :query, :bool, :filter) do
              {
                term: {
                  type: {
                    _name: context.name(:doc, :is_a, doc_type),
                    value: doc_type
                  }
                }
              }
            end
          end
        end

        # Caution: use this method with care.
        # Only use if `traversal_ids` is predetermined and on scopes that don't have visibility checks.
        # Prefer to use `by_search_level_and_membership` which takes care of visibility and membership.
        def by_traversal_ids(query_hash:, options:)
          return query_hash unless options[:traversal_ids]

          traversal_ids_ancestry_filter(query_hash, options[:traversal_ids], options)
        end

        def by_noteable_type(query_hash:, options:)
          noteable_type = options[:noteable_type]
          return query_hash unless noteable_type

          context.name(:filters) do
            query_hash[:_source] = ['noteable_id']
            query_hash[:size] = options.fetch(:related_size, DEFAULT_RELATED_SIZE)

            add_filter(query_hash, :query, :bool, :filter) do
              {
                term: {
                  noteable_type: {
                    _name: context.name(:related, noteable_type.downcase),
                    value: noteable_type
                  }
                }
              }
            end
          end
        end

        private

        # users without read_cross_project permission may not perform global and group searches
        # https://docs.gitlab.com/administration/settings/external_authorization/
        def cross_project_search_restricted_for_user?(user:, search_level:)
          [:global, :group].include?(search_level) && !Ability.allowed?(user, :read_cross_project)
        end

        def match_none_filter(query_hash)
          add_filter(query_hash, :query, :bool, :filter) do
            { match_none: {} }
          end
        end

        def group_ids_user_has_min_access_as(access_level:, user:, group_ids:)
          finder_params = { min_access_level: access_level }
          if group_ids.present?
            finder_params[:filter_group_ids] =
              Group.id_in(group_ids.uniq).map(&:self_and_descendants_ids).uniq
          end

          ::GroupsFinder.new(user, finder_params).execute.pluck("#{Group.table_name}.#{Group.primary_key}") # rubocop:disable CodeReuse/ActiveRecord -- we need pluck only the ids from the finder
        end

        def projects_for_user(user, options)
          return [] unless user

          search_level = options.fetch(:search_level).to_sym
          authorized_projects = ::Search::ProjectsFinder.new(user: user).execute
          case search_level
          when :global
            authorized_projects
          when :group
            namespace_ids = options[:group_ids]
            projects = Project.in_namespace(namespace_ids)
            if projects.present? && !projects.id_not_in(authorized_projects).exists?
              projects
            else
              Project.from_union([
                authorized_projects.in_namespace(namespace_ids),
                authorized_projects.by_any_overlap_with_traversal_ids(namespace_ids)
              ])
            end
          when :project
            project_ids = options[:project_ids]
            projects = Project.id_in(project_ids)
            if projects.present? && !projects.id_not_in(authorized_projects).exists?
              projects
            else
              authorized_projects.id_in(project_ids)
            end
          end
        end

        def authorized_namespace_ids(user, group_ids)
          return [] unless user && group_ids.present?

          authorized_ids = user.authorized_groups.pluck_primary_key.to_set
          authorized_ids.intersection(group_ids.to_set).to_a
        end

        # Builds an elasticsearch query that will select child documents from a
        # set of projects, taking user access rules into account.
        def project_ids_filter(query_hash, options)
          context.name(:project) do
            project_query = project_ids_query(options)

            add_filter(query_hash, :query, :bool, :filter) do
              # Some models have denormalized project permissions into the
              # document so that we do not need to use joins
              if options[:no_join_project]
                project_query[:_name] = context.name
                {
                  bool: project_query
                }
              else
                {
                  has_parent: {
                    _name: "#{context.name}:parent",
                    parent_type: "project",
                    query: {
                      bool: project_query
                    }
                  }
                }
              end
            end
          end
        end

        # Builds an elasticsearch query that will select projects the user is
        # granted access to.
        #
        # If a project feature(s) is specified, it indicates interest in child
        # documents gated by that project feature - e.g., "issues". The feature's
        # visibility level must be taken into account.
        def project_ids_query(options)
          user = options[:current_user]
          project_ids = options[:project_ids]
          public_and_internal_projects = options[:public_and_internal_projects]
          features = options[:features]
          no_join_project = options[:no_join_project]
          project_id_field = options[:project_id_field]
          project_visibility_level_field = options.fetch(:project_visibility_level_field, PROJECT_VISIBILITY_FIELD)

          scoped_project_ids = scoped_project_ids(user, project_ids)

          # At least one condition must be present, so pick no projects for
          # anonymous users.
          # Pick private, internal and public projects the user is a member of.
          # Pick all private projects for admins & auditors.
          conditions = pick_projects_by_membership(
            scoped_project_ids,
            user, no_join_project,
            features: features,
            project_id_field: project_id_field,
            project_visibility_level_field: project_visibility_level_field
          )

          if public_and_internal_projects
            context.name(:visibility) do
              # Skip internal projects for anonymous and external users.
              # Others are given access to all internal projects.
              #
              # Admins & auditors get access to internal projects even
              # if the feature is private.
              if user && !user.external?
                conditions += pick_projects_by_visibility(Project::INTERNAL, user, features,
                  project_visibility_level_field: project_visibility_level_field)
              end

              # All users, including anonymous, can access public projects.
              # Admins & auditors get access to public projects where the feature is
              # private.
              conditions += pick_projects_by_visibility(Project::PUBLIC, user, features,
                project_visibility_level_field: project_visibility_level_field)
            end
          end

          { should: conditions }
        end

        # Most users come with a list of projects they are members of, which may
        # be a mix of public, internal or private. Grant access to them all, as
        # long as the project feature is not disabled.
        #
        # Admins & auditors are given access to all private projects. Access to
        # internal or public projects where the project feature is private is not
        # granted here.
        def pick_projects_by_membership(
          project_ids, user, no_join_project, project_visibility_level_field:, features: nil, project_id_field: nil)
          # This method is used to construct a query on the join as well as query
          # on top level doc. When querying top level doc the project's ID is
          # used from project_id_field with the default value of `project_id`
          # When joining it is just `id`.
          id_field = if no_join_project
                       project_id_field || PROJECT_ID_FIELD
                     else
                       :id
                     end

          if features.nil?
            if project_ids == :any
              return [{ term: { project_visibility_level_field => { _name: context.name(:any),
                                                                    value: Project::PRIVATE } } }]
            end

            return [{ terms: { _name: context.name(:membership, :id), id_field => project_ids } }]
          end

          Array(features).map do |feature|
            condition =
              if project_ids == :any
                { term: { project_visibility_level_field => { _name: context.name(:any), value: Project::PRIVATE } } }
              else
                {
                  terms: {
                    _name: context.name(:membership, :id),
                    id_field => filter_project_ids_by_feature(project_ids, user, feature)
                  }
                }
              end

            limit = {
              terms: {
                _name: context.name(feature, :enabled_or_private),
                "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
              }
            }

            {
              bool: {
                filter: [condition, limit]
              }
            }
          end
        end

        # Grant access to projects of the specified visibility level to the user.
        #
        # If a project feature is specified, access is only granted if the feature
        # is enabled or, for admins & auditors, private.
        def pick_projects_by_visibility(visibility, user, features, project_visibility_level_field:)
          context.name(visibility) do
            condition = { term: { project_visibility_level_field => { _name: context.name, value: visibility } } }

            limit_by_feature(condition, features, include_members_only: user&.can_read_all_resources?)
          end
        end

        # If a project feature(s) is specified, access is dependent on its visibility
        # level being enabled (or private if `include_members_only: true`).
        #
        # This method is a no-op if no project feature is specified.
        # It accepts an array of features or a single feature, when an array is provided
        # it queries if any of the features is enabled.
        #
        # Always denies access to projects when the features are disabled - even to
        # admins & auditors - as stale child documents may be present.
        def limit_by_feature(condition, features, include_members_only:)
          return [condition] unless features

          features = Array(features)
          features.map do |feature|
            context.name(feature, :access_level) do
              limit =
                if include_members_only
                  {
                    terms: {
                      _name: context.name(:enabled_or_private),
                      "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                    }
                  }
                else
                  {
                    term: {
                      "#{feature}_access_level" => {
                        _name: context.name(:enabled),
                        value: ::ProjectFeature::ENABLED
                      }
                    }
                  }
                end

              {
                bool: {
                  _name: context.name,
                  filter: [condition, limit]
                }
              }
            end
          end
        end

        def traversal_ids_filter(query_hash, namespaces, options)
          namespace_ancestry = namespaces.map(&:elastic_namespace_ancestry)

          context.name(:reject_projects) do
            add_filter(query_hash, :query, :bool, :must_not) do
              rejected_project_filter(namespaces, options)
            end
          end

          traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
        end

        # Useful when performing group searches by traversal_id to prevent
        # access to projects in the group hierarchy that the user does not have
        # permission to view.
        def rejected_project_filter(namespaces, options)
          current_user = options[:current_user]
          scoped_project_ids = scoped_project_ids(current_user, options[:project_ids])
          return {} if scoped_project_ids == :any

          project_ids = []
          Array.wrap(options[:features]).each do |feature|
            project_ids.concat(filter_project_ids_by_feature(scoped_project_ids, current_user, feature))
          end

          rejected_ids = namespaces.flat_map do |namespace|
            namespace.all_project_ids_except(project_ids).pluck_primary_key
          end

          {
            terms: {
              _name: context.name,
              "#{options[:project_id_field]}": rejected_ids
            }
          }
        end

        def traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
          return query_hash if namespace_ancestry.empty?

          context.name(:namespace) do
            add_filter(query_hash, :query, :bool, :filter) do
              {
                bool: {
                  should: ancestry_filter(namespace_ancestry,
                    traversal_id_field: options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)),
                  minimum_should_match: 1
                }
              }
            end
          end
        end

        def filter_project_ids_by_feature(project_ids, user, feature)
          Project
            .id_in(project_ids)
            .filter_by_feature_visibility(feature, user)
            .pluck_primary_key
        end

        def project_ids_for_features(projects, user, features)
          project_ids = projects.pluck_primary_key

          allowed_ids = []
          features.each do |feature|
            allowed_ids.concat(filter_project_ids_by_feature(project_ids, user, feature))
          end

          abilities = features.map { |feature| ability_to_access_feature(feature) }

          allowed_ids.concat(filter_project_ids_by_abilities(projects, user, abilities))
          allowed_ids.uniq
        end

        def filter_project_ids_by_abilities(projects, user, target_abilities)
          return [] if target_abilities.empty? || user.blank?

          actual_abilities = ::Authz::Project.new(user, scope: projects).permitted

          projects.filter_map do |project|
            project.id if (actual_abilities[project.id] || []).intersection(target_abilities).any?
          end
        end

        def ability_to_access_feature(feature)
          case feature&.to_sym
          when :repository
            :read_code
          end
        end

        def find_labels_by_name(names, options)
          raise ArgumentError, 'search_level is a required option' unless options.key?(:search_level)

          return [] if names.empty?

          search_level = options[:search_level].to_sym
          finder_params = { name: names }

          labels = case search_level
                   when :global
                     find_global_labels(finder_params)
                   when :group
                     find_group_labels(finder_params, options[:group_ids])
                   when :project
                     find_project_labels(finder_params, options[:group_ids], options[:project_ids])
                   else
                     raise ArgumentError, 'Invalid search_level option provided'
                   end

          group_labels_by_name(labels)
        end

        def find_global_labels(finder_params)
          LabelsFinder.new(nil, finder_params).execute(skip_authorization: true)
        end

        def find_group_labels(finder_params, group_ids)
          return find_global_labels(finder_params) if group_ids.blank?

          finder_params[:include_descendant_groups] = true
          finder_params[:include_ancestor_groups] = true

          group_ids.flat_map do |group_id|
            LabelsFinder.new(nil, finder_params.merge(group_id: group_id)).execute(skip_authorization: true)
          end
        end

        def find_project_labels(finder_params, group_ids, project_ids)
          # try group labels if no project_ids are provided or set to :any which means user has admin access
          return find_group_labels(finder_params, group_ids) if project_ids.blank? || project_ids == :any

          finder_params[:include_descendant_groups] = false
          finder_params[:include_ancestor_groups] = true

          project_ids.flat_map do |project_id|
            LabelsFinder.new(nil, finder_params.merge(project_id: project_id)).execute(skip_authorization: true)
          end
        end

        def group_labels_by_name(labels)
          labels.each_with_object(Hash.new { |h, k| h[k] = [] }) do |label, hash|
            hash[label.name] << label.id
          end
        end

        def search_level_filter(query_hash:, options:)
          user = options[:current_user]
          search_level = options[:search_level].to_sym
          namespace_ids = options[:group_ids]
          project_ids = scoped_project_ids(user, options[:project_ids])

          add_filter(query_hash, :query, :bool, :filter) do
            context.name(:filters, :level, search_level) do
              case search_level
              when :global
                nil
              when :group
                raise ArgumentError, 'No group_ids provided for group level search' if namespace_ids.empty?

                namespaces = Namespace.id_in(namespace_ids)
                traversal_ids = namespaces.map(&:elastic_namespace_ancestry)
                { bool:
                  { _name: context.name,
                    minimum_should_match: 1,
                    should: ancestry_filter(traversal_ids,
                      traversal_id_field: options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)) } }
              when :project
                raise ArgumentError, 'No project_ids provided for project level search' if project_ids.empty?

                { terms: { _name: context.name, project_id: project_ids } }
              end
            end
          end
        end

        def build_membership_filter(options:)
          user = options[:current_user]
          search_level = options[:search_level].to_sym

          membership_filter = Search::Elastic::BoolExpr.new

          context.name(:filters, :permissions, search_level) do
            membership_filter = build_project_and_group_membership_filters(filter: membership_filter,
              user: user, options: options)
            membership_filter = build_public_and_internal_filters(filter: membership_filter, user: user,
              options: options)
          end

          membership_filter
        end

        # add visibility level filter for public and internal visibility, does not include group or project membership
        # admins do not add any filter
        # logged-in users get PUBLIC and INTERNAL
        # anonymous and logged in external users only get PUBLIC
        def add_visibility_level_filter(filter:, user:, visibility_level_field:)
          return if user&.can_read_all_resources?

          add_filter(filter, :filter) do
            if user && !user.external?
              { terms: {
                _name: context.name(visibility_level_field, :public_and_internal),
                "#{visibility_level_field}": [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL]
              } }
            else
              { terms: {
                _name: context.name(visibility_level_field, :public),
                "#{visibility_level_field}": [::Gitlab::VisibilityLevel::PUBLIC]
              } }
            end
          end
        end

        # add project feature visibility filter, does not include group or project membership
        # admins get ENABLED and PRIVATE, all other users get ENABLED
        def add_project_feature_visibility_filter(filter:, features:, user:)
          return if features.blank?

          access_level_allowed = [::ProjectFeature::ENABLED]
          access_context_name = :enabled
          if user&.can_read_all_resources?
            access_level_allowed << ::ProjectFeature::PRIVATE
            access_context_name = :enabled_or_private
          end

          features.each do |feature|
            add_filter(filter, :should) do
              {
                terms: {
                  _name: context.name(:"#{feature}_access_level", access_context_name),
                  "#{feature}_access_level": access_level_allowed
                }
              }
            end
          end
        end

        def build_public_and_internal_filters(filter:, user:, options:)
          features = Array.wrap(options[:features])
          visibility_level_field = options.fetch(:project_visibility_level_field, PROJECT_VISIBILITY_FIELD)

          new_filter = filter.dup

          # for admins and anonymous users, do not nest the query
          if user.nil? || user&.can_read_all_resources?
            add_visibility_level_filter(filter: new_filter, user: user, visibility_level_field: visibility_level_field)
            add_project_feature_visibility_filter(filter: new_filter, user: user, features: features)

            return new_filter
          end

          public_and_internal_filter = Search::Elastic::BoolExpr.new
          add_visibility_level_filter(filter: public_and_internal_filter, user: user,
            visibility_level_field: visibility_level_field)
          add_project_feature_visibility_filter(filter: public_and_internal_filter, user: user, features: features)

          add_filter(new_filter, :should) do
            public_and_internal_filter.to_bool_query
          end

          new_filter
        end

        def build_project_and_group_membership_filters(filter:, user:, options:)
          return filter if user&.can_read_all_resources?

          new_filter = filter.dup
          add_group_membership_filters(new_filter, user, options)
          add_project_membership_filters(new_filter, user, options)

          new_filter
        end

        def add_group_membership_filters(membership_filters, user, options)
          groups = ::Search::GroupsFinder.new(user: user).execute

          return unless groups.exists?

          features = Array.wrap(options[:features])
          if features.empty?
            add_filter(membership_filters, :should) do
              traversal_id_field = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)
              traversal_ids = groups.map(&:elastic_namespace_ancestry)

              ancestry_filter(traversal_ids, traversal_id_field: traversal_id_field)
            end

            return
          end

          process_features_for_groups(
            membership_filters: membership_filters,
            user: user,
            groups: groups,
            features: features,
            options: options
          )
        end

        def process_features_for_groups(membership_filters:, user:, groups:, features:, options:)
          user_abilities = ::Authz::Group.new(user, scope: groups).permitted

          required_feature_access_levels = build_required_feature_access_levels(features)
          group_ids_by_access_level = required_feature_access_levels.index_with do |level|
            groups.by_min_access_level(user, level).pluck_primary_key
          end

          features.each do |feature|
            access_levels = get_feature_access_levels(feature)

            allowed_group_ids = group_ids_by_access_level[access_levels[:project]]
            allowed_group_ids.concat(allowed_ids_by_ability(feature:, user_abilities:))

            private_allowed_group_ids = if access_levels[:project] != access_levels[:private_project]
                                          group_ids_by_access_level[access_levels[:private_project]] +
                                            allowed_ids_by_ability(feature:, user_abilities:)
                                        else
                                          []
                                        end

            add_feature_access_filter_for_groups(
              membership_filters: membership_filters,
              feature: feature,
              allowed_group_ids: allowed_group_ids,
              private_allowed_group_ids: private_allowed_group_ids,
              access_levels: access_levels,
              options: options
            )
          end
        end

        def build_required_feature_access_levels(features)
          features.each_with_object(Set.new) do |feature, required_feature_access_levels|
            access_levels = get_feature_access_levels(feature)

            required_feature_access_levels << access_levels[:project]
            required_feature_access_levels << access_levels[:private_project]
          end
        end

        def get_feature_access_levels(feature)
          {
            project: ProjectFeature.required_minimum_access_level(feature),
            private_project: ProjectFeature.required_minimum_access_level_for_private_project(feature)
          }
        end

        def allowed_ids_by_ability(feature:, user_abilities:)
          target_ability = FEATURE_TO_ABILITY_MAP[feature.to_sym]
          user_abilities.filter_map do |id, abilities|
            id if abilities.include?(target_ability)
          end
        end

        def add_feature_access_filter_for_groups(
          membership_filters:, feature:, allowed_group_ids:,
          private_allowed_group_ids:, access_levels:, options:)
          return if allowed_group_ids.blank? && private_allowed_group_ids.blank?

          traversal_groups = {}

          if allowed_group_ids.present?
            groups = Group.id_in(allowed_group_ids)
            traversal_ids = get_traversal_ids_for_search_level(groups, options)

            access_contexts = build_access_contexts(access_levels)
            consolidate_access_permissions(traversal_groups, traversal_ids, access_contexts)
          end

          if private_allowed_group_ids.present? && access_levels[:project] != access_levels[:private_project]
            private_groups = Group.id_in(private_allowed_group_ids)
            private_traversal_ids = get_traversal_ids_for_search_level(private_groups, options)

            consolidate_access_permissions(traversal_groups, private_traversal_ids, :private)
          end

          consolidated_traversal_ids = {}
          traversal_groups.each do |traversal_id, config|
            key = config[:access_contexts].to_a.join('_')
            consolidated_traversal_ids[key] ||= {
              traversal_ids: Set.new,
              access_contexts: config[:access_contexts]
            }
            consolidated_traversal_ids[key][:traversal_ids].add(traversal_id)
          end

          add_filter(membership_filters, :should) do
            build_public_and_internal_group_filters(
              public_and_internal_configs: consolidated_traversal_ids['public_internal'],
              feature: feature, options: options)
          end

          add_filter(membership_filters, :should) do
            build_private_group_filters(private_configs: consolidated_traversal_ids['public_internal_private'],
              feature: feature, options: options)
          end
        end

        def build_public_and_internal_group_filters(public_and_internal_configs:, feature:, options:)
          return if public_and_internal_configs.blank?

          filter = Search::Elastic::BoolExpr.new
          visibility_level_field = options.fetch(:project_visibility_level_field, PROJECT_VISIBILITY_FIELD)
          traversal_id_field = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)

          context.name(:public_and_internal_access) do
            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:"#{feature}_access_level", :enabled_or_private),
                  "#{feature}_access_level": [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                }
              }
            end

            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:project_visibility_level, :public_or_internal),
                  "#{visibility_level_field}": [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL]
                }
              }
            end

            public_and_internal_configs[:traversal_ids].each do |traversal_id|
              add_filter(filter, :should) do
                {
                  prefix: {
                    "#{traversal_id_field}": {
                      _name: context.name(:ancestry_filter, :descendants),
                      value: traversal_id
                    }
                  }
                }
              end
            end
          end

          filter.to_bool_query
        end

        def build_private_group_filters(private_configs:, feature:, options:)
          return if private_configs.blank?

          filter = Search::Elastic::BoolExpr.new
          traversal_id_field = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)

          context.name(:private_access) do
            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:"#{feature}_access_level", :enabled_or_private),
                  "#{feature}_access_level": [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                }
              }
            end

            private_configs[:traversal_ids].each do |traversal_id|
              add_filter(filter, :should) do
                {
                  prefix: {
                    "#{traversal_id_field}": {
                      _name: context.name(:ancestry_filter, :descendants),
                      value: traversal_id
                    }
                  }
                }
              end
            end
          end

          filter.to_bool_query
        end

        def consolidate_access_permissions(access_groups, collection, access_contexts)
          collection.each do |item_id|
            access_groups[item_id] ||= {
              access_contexts: Set.new
            }
            access_groups[item_id][:access_contexts].merge(Array.wrap(access_contexts))
          end
        end

        def add_project_membership_filters(membership_filters, user, options)
          return unless user

          projects = projects_for_user(user, options)
          return unless projects.exists?

          features = Array.wrap(options[:features])

          if features.empty?
            project_id_field = options.fetch(:project_id_field, PROJECT_ID_FIELD)
            add_filter(membership_filters, :should) do
              {
                terms: {
                  _name: context.name(:project, :member),
                  "#{project_id_field}": projects.pluck_primary_key
                }
              }
            end

            return
          end

          process_features_for_projects(membership_filters: membership_filters, user: user, projects: projects,
            features: features, options: options)
        end

        def process_features_for_projects(membership_filters:, user:, projects:, features:, options:)
          user_abilities = ::Authz::Project.new(user, scope: projects).permitted

          required_feature_access_levels = build_required_feature_access_levels(features)
          project_ids_by_access_level = required_feature_access_levels.index_with do |level|
            projects.where_exists(user.authorizations_for_projects(min_access_level: level)).pluck_primary_key
          end

          features.each do |feature|
            access_levels = get_feature_access_levels(feature)

            allowed_project_ids = project_ids_by_access_level[access_levels[:project]]
            allowed_project_ids.concat(allowed_ids_by_ability(feature:, user_abilities:))

            private_allowed_project_ids = if access_levels[:project] != access_levels[:private_project]
                                            project_ids_by_access_level[access_levels[:private_project]] +
                                              allowed_ids_by_ability(feature:, user_abilities:)
                                          else
                                            []
                                          end

            add_feature_access_filter_for_projects(
              membership_filters: membership_filters,
              feature: feature,
              allowed_project_ids: allowed_project_ids,
              private_allowed_project_ids: private_allowed_project_ids,
              access_levels: access_levels,
              options: options
            )
          end
        end

        def add_feature_access_filter_for_projects(
          membership_filters:, feature:, allowed_project_ids:,
          private_allowed_project_ids:, access_levels:, options:)
          return if allowed_project_ids.blank? && private_allowed_project_ids.blank?

          project_access_groups = {}

          access_contexts = build_access_contexts(access_levels)
          consolidate_access_permissions(project_access_groups, allowed_project_ids, access_contexts)

          if access_levels[:project] != access_levels[:private_project]
            consolidate_access_permissions(project_access_groups, private_allowed_project_ids, :private)
          end

          consolidated_projects = {}
          project_access_groups.each do |project_id, config|
            key = config[:access_contexts].to_a.join('_')
            consolidated_projects[key] ||= {
              project_ids: Set.new,
              access_contexts: config[:access_contexts]
            }
            consolidated_projects[key][:project_ids].add(project_id)
          end

          add_filter(membership_filters, :should) do
            build_public_and_internal_project_filters(
              public_and_internal_configs: consolidated_projects['public_internal'],
              feature: feature, options: options)
          end

          add_filter(membership_filters, :should) do
            build_private_project_filters(private_configs: consolidated_projects['public_internal_private'],
              feature: feature, options: options)
          end
        end

        def build_public_and_internal_project_filters(public_and_internal_configs:, feature:, options:)
          return if public_and_internal_configs.blank?

          filter = Search::Elastic::BoolExpr.new
          visibility_level_field = options.fetch(:project_visibility_level_field, PROJECT_VISIBILITY_FIELD)
          project_id_field = options.fetch(:project_id_field, PROJECT_ID_FIELD)

          context.name(:public_and_internal_access) do
            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:"#{feature}_access_level", :enabled_or_private),
                  "#{feature}_access_level": [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                }
              }
            end

            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:project_visibility_level, :public_or_internal),
                  "#{visibility_level_field}": [::Gitlab::VisibilityLevel::PUBLIC, ::Gitlab::VisibilityLevel::INTERNAL]
                }
              }
            end

            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:project, :member),
                  "#{project_id_field}": public_and_internal_configs[:project_ids].to_a
                }
              }
            end
          end

          filter.to_bool_query
        end

        def build_private_project_filters(private_configs:, feature:, options:)
          return if private_configs.blank?

          filter = Search::Elastic::BoolExpr.new
          project_id_field = options.fetch(:project_id_field, PROJECT_ID_FIELD)

          context.name(:private_access) do
            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:"#{feature}_access_level", :enabled_or_private),
                  "#{feature}_access_level": [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                }
              }
            end

            add_filter(filter, :filter) do
              {
                terms: {
                  _name: context.name(:project, :member),
                  "#{project_id_field}": private_configs[:project_ids].to_a
                }
              }
            end
          end

          filter.to_bool_query
        end

        def build_access_contexts(access_levels)
          [:public, :internal].tap do |access_contexts|
            access_contexts << :private if access_levels[:project] == access_levels[:private_project]
          end
        end

        # Builds ES queries for label filtering with wildcard support for scoped labels.
        #
        # Supports both exact matching for regular labels
        # and wildcard prefix matching for scoped labels like:
        # - "advanced search" (exact match)
        # - "workflow::complete" (exact match)
        # - "workflow::in dev" (exact match)
        # - "workflow::*" (prefix match for all labels starting with "workflow::")
        #
        # For now, it uses `prefix` queries for wildcard matching as they provide optimal performance
        # for keyword fields when doing "starts with" operations.
        #
        # This implementation follows the same pattern as the PostgreSQL version in
        # ee/app/finders/ee/issuables/label_filter.rb
        def build_label_queries(label_names)
          label_names.map do |label_name|
            if scoped_label_wildcard?(label_name)
              prefix = label_name[0...-1]
              {
                prefix: {
                  label_names: prefix
                }
              }
            else
              {
                term: {
                  label_names: label_name
                }
              }
            end
          end
        end

        def scoped_label_wildcard?(label_name)
          # Follows the existing pattern of SCOPED_LABEL_SEPARATOR in ee/app/models/ee/label.rb
          # and SCOPED_LABEL_WILDCARD in ee/app/finders/ee/issuables/label_filter.rb#extract_scoped_label_wildcards
          label_name.end_with?('::*')
        end
      end
    end
  end
end
