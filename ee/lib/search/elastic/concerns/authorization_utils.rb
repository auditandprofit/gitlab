# frozen_string_literal: true

module Search
  module Elastic
    module Concerns
      module AuthorizationUtils
        private

        def project_ids_for_user(user, options)
          return [] unless user

          search_level = options.fetch(:search_level).to_sym
          authorized_projects = ::Search::ProjectsFinder.new(user: user).execute

          projects = case search_level
                     when :global
                       authorized_projects
                     when :group
                       namespace_ids = options[:group_ids]
                       namespace_projects = Project.in_namespace(namespace_ids)
                       if namespace_projects.present? && !namespace_projects.id_not_in(authorized_projects).exists?
                         namespace_projects
                       else
                         Project.from_union([
                           authorized_projects.in_namespace(namespace_ids),
                           authorized_projects.by_any_overlap_with_traversal_ids(namespace_ids)
                         ])
                       end
                     when :project
                       project_ids = options[:project_ids]
                       projects_searched = Project.id_in(project_ids)
                       if projects_searched.present? && !projects_searched.id_not_in(authorized_projects).exists?
                         projects_searched
                       else
                         authorized_projects.id_in(project_ids)
                       end
                     end

          features = Array.wrap(options[:features])
          return projects.pluck_primary_key unless features.present?

          project_ids_for_features(projects, user, features)
        end

        # @deprecated - use by_search_level_and_membership - this method is kept for legacy authorization
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

        def filter_project_ids_by_feature(project_ids, user, feature)
          Project
            .id_in(project_ids)
            .filter_by_feature_visibility(feature, user)
            .pluck_primary_key
        end

        def scoped_project_ids(current_user, project_ids)
          return :any if project_ids == :any

          project_ids ||= []

          # When reading cross project is not allowed, only allow searching a
          # a single project, so the `:read_*` ability is only checked once.
          return [] if !Ability.allowed?(current_user, :read_cross_project) && project_ids.size > 1

          project_ids
        end

        def ability_to_access_feature(feature)
          case feature&.to_sym
          when :repository
            :read_code
          end
        end

        def filter_project_ids_by_abilities(projects, user, target_abilities)
          return [] if target_abilities.empty? || user.blank?

          actual_abilities = ::Authz::Project.new(user, scope: projects).permitted

          projects.filter_map do |project|
            project.id if (actual_abilities[project.id] || []).intersection(target_abilities).any?
          end
        end

        def traversal_ids_for_user(user, options)
          return [] unless user

          finder_params = {
            features: Array.wrap(options[:features]),
            min_access_level: options[:min_access_level]
          }
          authorized_groups = ::Search::GroupsFinder.new(user: user, params: finder_params).execute

          get_traversal_ids_for_search_level(authorized_groups, options)
        end

        def get_traversal_ids_for_search_level(authorized_groups, options)
          search_level = options.fetch(:search_level).to_sym

          case search_level
          when :global
            authorized_traversal_ids_for_global(authorized_groups)
          when :group
            authorized_traversal_ids_for_groups(authorized_groups, options[:group_ids])
          when :project
            authorized_traversal_ids_for_projects(authorized_groups, options[:project_ids])
          end.map { |id| "#{id.join('-')}-" }
        end

        def authorized_traversal_ids_for_global(authorized_groups)
          ::Namespaces::Traversal::TrieNode.build(authorized_groups.map(&:traversal_ids)).to_a
        end

        def authorized_traversal_ids_for_groups(authorized_groups, namespace_ids)
          namespaces = Namespace.id_in(namespace_ids)

          return namespaces.map(&:traversal_ids) unless namespaces.id_not_in(authorized_groups).exists?

          authorized_trie = ::Namespaces::Traversal::TrieNode.build(authorized_groups.map(&:traversal_ids))

          [].tap do |allowed_traversal_ids|
            namespaces.map do |namespace|
              traversal_ids = namespace.traversal_ids
              if authorized_trie.covered?(traversal_ids)
                allowed_traversal_ids << traversal_ids
                next
              end

              allowed_traversal_ids.concat(authorized_trie.prefix_search(traversal_ids))
            end
          end
        end

        def authorized_traversal_ids_for_projects(authorized_groups, project_ids)
          namespace_ids = Project.id_in(project_ids).select(:namespace_id)
          namespaces = Namespace.id_in(namespace_ids)

          return namespaces.map(&:traversal_ids) unless namespaces.id_not_in(authorized_groups).exists?

          authorized_trie = ::Namespaces::Traversal::TrieNode.build(authorized_groups.map(&:traversal_ids))

          namespaces.map(&:traversal_ids).select { |s| authorized_trie.covered?(s) }
        end

        def ancestry_filter(namespace_ancestry, traversal_id_field:)
          context.name(:ancestry_filter) do
            namespace_ancestry.map do |namespace_ids|
              {
                prefix: {
                  "#{traversal_id_field}": {
                    _name: context.name(:descendants),
                    value: namespace_ids
                  }
                }
              }
            end
          end
        end

        def authorized_namespace_ids_for_project_group_ancestry(user)
          authorized_groups = ::Search::GroupsFinder.new(user: user).execute
          authorized_projects = ::Search::ProjectsFinder.new(user: user).execute
          authorized_project_namespaces = Namespace.id_in(authorized_projects.select(:namespace_id))

          # shortcut the filter if the user is authorized to see a namespace in the hierarchy already
          return [] unless authorized_project_namespaces.id_not_in(authorized_groups).exists?

          authorized_trie = ::Namespaces::Traversal::TrieNode.build(authorized_groups.map(&:traversal_ids))
          not_covered_namespaces = authorized_project_namespaces.reject do |namespace|
            authorized_trie.covered?(namespace.traversal_ids)
          end

          not_covered_namespaces.pluck(:traversal_ids).flatten.uniq # rubocop:disable CodeReuse/ActiveRecord -- traversal_ids are needed to generate namespace_id array
        end
      end
    end
  end
end
