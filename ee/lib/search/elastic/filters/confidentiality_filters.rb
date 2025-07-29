# frozen_string_literal: true

module Search
  module Elastic
    module Filters
      module ConfidentialityFilters
        extend ActiveSupport::Concern

        class_methods do
          include ::Elastic::Latest::QueryContext::Aware
          include Search::Elastic::Concerns::FilterUtils
          include Search::Elastic::Concerns::AuthorizationUtils

          def by_project_confidentiality(query_hash:, options:)
            confidential = options[:confidential]
            user = options[:current_user]
            project_ids = options[:project_ids]

            context.name(:filters) do
              if [true, false].include?(confidential)
                add_filter(query_hash, :query, :bool, :filter) do
                  { term: { confidential: confidential } }
                end
              end

              # There might be an option to not add confidentiality filter for project level search
              next query_hash if user&.can_read_all_resources?

              scoped_project_ids = scoped_project_ids(user, project_ids)
              authorized_project_ids = authorized_project_ids(user, scoped_project_ids)

              non_confidential_filter = {
                term: { confidential: { _name: context.name(:non_confidential), value: false } }
              }

              filter = if user
                         confidential_filter = {
                           bool: {
                             must: [
                               { term: { confidential: { _name: context.name(:confidential), value: true } } },
                               {
                                 bool: {
                                   should: [
                                     { term:
                                       { author_id: {
                                         _name: context.name(:confidential, :as_author),
                                         value: user.id
                                       } } },
                                     { term:
                                       { assignee_id: {
                                         _name: context.name(:confidential, :as_assignee),
                                         value: user.id
                                       } } },
                                     { terms: { _name: context.name(:confidential, :project, :membership, :id),
                                                project_id: authorized_project_ids } }
                                   ]
                                 }
                               }
                             ]
                           }
                         }

                         {
                           bool: {
                             should: [
                               non_confidential_filter,
                               confidential_filter
                             ]
                           }
                         }
                       else
                         non_confidential_filter
                       end

              add_filter(query_hash, :query, :bool, :filter) do
                filter
              end
            end
          end

          def by_group_level_confidentiality(query_hash:, options:)
            user = options[:current_user]
            return query_hash if user&.can_read_all_resources?

            context.name(:filters, :confidentiality, :groups) do
              traversal_ids_prefix = options.fetch(:traversal_ids_prefix, TRAVERSAL_IDS_FIELD)
              filter = Search::Elastic::BoolExpr.new
              filter.minimum_should_match = 1

              # anonymous user, public groups, non-confidential
              add_filter(filter, :should) do
                {
                  bool: {
                    _name: context.name(:non_confidential, :public),
                    must: [
                      { term: { confidential: { value: false } } },
                      { term: { namespace_visibility_level: { value: ::Gitlab::VisibilityLevel::PUBLIC } } }
                    ]
                  }
                }
              end

              if user && !user.external?
                # logged in user, public groups, non-confidential
                add_filter(filter, :should) do
                  {
                    bool: {
                      _name: context.name(:non_confidential, :internal),
                      must: [
                        { term: { confidential: { value: false } } },
                        { term: { namespace_visibility_level: { value: ::Gitlab::VisibilityLevel::INTERNAL } } }
                      ]
                    }
                  }
                end
              end

              if user
                # logged in user, private groups, non-confidential
                add_filter(filter, :should) do
                  min_access_for_non_confidential = options[:min_access_level_non_confidential]
                  non_confidential_options = options.merge(min_access_level: min_access_for_non_confidential)
                  traversal_ids = traversal_ids_for_user(user, non_confidential_options)
                  next if traversal_ids.empty?

                  context.name(:non_confidential, :private) do
                    {
                      bool: {
                        _name: context.name,
                        must: [
                          { term: { confidential: { value: false } } }
                        ],
                        should: ancestry_filter(traversal_ids, traversal_id_field: traversal_ids_prefix),
                        minimum_should_match: 1
                      }
                    }
                  end
                end

                # logged-in user, private projects ancestor hierarchy, non-confidential
                add_filter(filter, :should) do
                  authorized_project_ancestry_namespace_ids = authorized_namespace_ids_for_project_group_ancestry(user)
                  next if authorized_project_ancestry_namespace_ids.empty?

                  context.name(:non_confidential, :private) do
                    {
                      bool: {
                        _name: context.name,
                        must: [
                          { term: { confidential: { value: false } } },
                          { terms: {
                            _name: context.name(:project, :membership),
                            namespace_id: authorized_project_ancestry_namespace_ids
                          } }
                        ]
                      }
                    }
                  end
                end

                # logged in user, private groups, confidential
                add_filter(filter, :should) do
                  min_access_for_confidential = options[:min_access_level_confidential]
                  confidential_options = options.merge(min_access_level: min_access_for_confidential)
                  traversal_ids = traversal_ids_for_user(user, confidential_options)

                  next if traversal_ids.empty?

                  context.name(:confidential, :private) do
                    {
                      bool: {
                        _name: context.name,
                        must: [
                          { term: { confidential: { value: true } } }
                        ],
                        should: ancestry_filter(traversal_ids, traversal_id_field: traversal_ids_prefix),
                        minimum_should_match: 1
                      }
                    }
                  end
                end
              end

              add_filter(query_hash, :query, :bool, :filter) do
                filter.to_bool_query
              end
            end
          end

          private

          def authorized_project_ids(current_user, scoped_project_ids)
            return [] unless current_user

            authorized_project_ids = current_user.authorized_projects(Gitlab::Access::REPORTER).pluck_primary_key.to_set

            # if the current search is limited to a subset of projects, we should do
            # confidentiality check for these projects.
            authorized_project_ids &= scoped_project_ids.to_set unless scoped_project_ids == :any

            authorized_project_ids.to_a
          end
        end
      end
    end
  end
end
