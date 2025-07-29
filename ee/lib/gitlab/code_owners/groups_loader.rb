# frozen_string_literal: true

module Gitlab
  module CodeOwners
    class GroupsLoader
      include Gitlab::Utils::StrongMemoize

      def initialize(project, names: nil)
        @project = project
        @names = names
      end

      def load_to(entries)
        entries.each do |entry|
          entry.add_matching_groups_from(groups)
        end
      end

      def groups
        return Group.none if names.blank?

        relations = [
          project.invited_groups.where_full_path_in(names, preload_routes: false)
        ]
        # Include the projects ancestor group(s) if they are listed as owners
        relations << project.group.self_and_ancestors.where_full_path_in(names, preload_routes: false) if project.group

        Group.from_union(relations).with_route.with_users
      end
      strong_memoize_attr :groups

      private

      attr_reader :names, :project
    end
  end
end
