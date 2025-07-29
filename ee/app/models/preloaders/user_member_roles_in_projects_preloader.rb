# frozen_string_literal: true

module Preloaders
  class UserMemberRolesInProjectsPreloader
    include Gitlab::Utils::StrongMemoize

    attr_reader :projects, :projects_relation, :user

    def initialize(projects:, user:)
      @projects = projects
      @user = user
    end

    def execute
      return {} if projects.blank? || user.blank?

      project_ids = projects.map { |project| project.respond_to?(:id) ? project.id : project }

      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: project_ids,
        default_value: []
      ) do |project_ids|
        abilities_for_user_grouped_by_project(project_ids)
      end
    end

    private

    def abilities_for_user_grouped_by_project(project_ids)
      @projects_relation = Project.select(:id, :namespace_id).id_in(project_ids)

      ::Namespaces::Preloaders::ProjectRootAncestorPreloader.new(projects_relation, :namespace).execute

      projects_with_traversal_ids = projects_relation.filter_map do |project|
        next unless custom_roles_enabled_on?(project)

        [project.id, Arel.sql("ARRAY[#{project.namespace.traversal_ids_as_sql}]")]
      end

      return {} if projects_with_traversal_ids.empty?

      value_list = Arel::Nodes::ValuesList.new(projects_with_traversal_ids)

      sql = <<~SQL
      SELECT project_ids.project_id, custom_permissions.permissions
        FROM (#{value_list.to_sql}) AS project_ids (project_id, namespace_ids),
        LATERAL (
          #{union_query}
        ) AS custom_permissions
      SQL

      grouped_by_project = ApplicationRecord.connection.select_all(sql).to_a.group_by do |h|
        h['project_id']
      end

      log_statistics(project_ids)

      grouped_by_project.transform_values do |values|
        project_permissions = values.map do |value|
          Gitlab::Json.parse(value['permissions']).select { |_, v| v }
        end

        project_permissions.inject(:merge).keys.map(&:to_sym) & enabled_project_permissions
      end
    end

    def union_query
      union_queries = []

      member = Member.select('member_roles.permissions')
        .with_user(user)

      project_member = member
        .joins(:member_role)
        .where(source_type: 'Project')
        .where('members.source_id = project_ids.project_id')
        .to_sql

      namespace_member = member
        .joins(:member_role)
        .where(source_type: 'Namespace')
        .where('members.source_id IN (SELECT UNNEST(project_ids.namespace_ids) as ids)')
        .to_sql

      if custom_role_for_group_link_enabled?
        group_link_join = member
          .joins('JOIN group_group_links ON members.source_id = group_group_links.shared_with_group_id')
          .where('group_group_links.shared_group_id IN (SELECT UNNEST(project_ids.namespace_ids) as ids)')

        invited_member_role = group_link_join
          .joins('JOIN member_roles ON member_roles.id = group_group_links.member_role_id')
          .where('access_level > group_access')
          .to_sql

        # when both roles are custom roles with the same base access level,
        # choose the source role as the max role
        source_member_role = group_link_join
          .joins('JOIN member_roles ON member_roles.id = members.member_role_id')
          .where('(access_level < group_access) OR ' \
            '(access_level = group_access AND group_group_links.member_role_id IS NOT NULL)')
          .to_sql

        union_queries.push(invited_member_role, source_member_role)
      end

      union_queries.push(project_member, namespace_member)

      union_queries.join(" UNION ALL ")
    end

    def custom_roles_enabled_on
      Hash.new do |hash, namespace|
        hash[namespace] = namespace&.should_process_custom_roles?
      end
    end
    strong_memoize_attr :custom_roles_enabled_on

    def custom_roles_enabled_on?(project)
      custom_roles_enabled_on[project&.root_ancestor]
    end

    def resource_key
      "member_roles_in_projects:user:#{user.id}"
    end

    def enabled_project_permissions
      MemberRole
        .all_customizable_project_permissions
        .filter { |permission| ::MemberRole.permission_enabled?(permission, user) }
    end
    strong_memoize_attr :enabled_project_permissions

    def custom_role_for_group_link_enabled?
      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        projects_relation.any? do |project|
          ::Feature.enabled?(:assign_custom_roles_to_group_links_saas, project.root_ancestor)
        end
      else
        ::Feature.enabled?(:assign_custom_roles_to_group_links_sm, :instance)
      end
    end

    def log_statistics(project_ids)
      ::Gitlab::AppLogger.info(
        class: self.class.name,
        user_id: user.id,
        projects_count: project_ids.length
      )
    end
  end
end
