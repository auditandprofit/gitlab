# frozen_string_literal: true

module Preloaders
  class UserMemberRolesInGroupsPreloader
    include Gitlab::Utils::StrongMemoize

    attr_reader :groups, :group_relation, :user

    def initialize(groups:, user:)
      @groups = groups
      @user = user
    end

    def execute
      return {} if groups.blank? || user.blank?

      group_ids = groups.map { |group| group.respond_to?(:id) ? group.id : group }

      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: group_ids,
        default_value: []
      ) do |group_ids|
        abilities_for_user_grouped_by_group(group_ids)
      end
    end

    private

    def abilities_for_user_grouped_by_group(group_ids)
      @group_relation = Group.id_in(group_ids)

      ::Namespaces::Preloaders::GroupRootAncestorPreloader.new(group_relation).execute

      groups_with_traversal_ids = group_relation.filter_map do |group|
        next unless group.root_ancestor.should_process_custom_roles?

        [group.id, Arel.sql("ARRAY[#{group.traversal_ids_as_sql}]")]
      end

      return {} if groups_with_traversal_ids.empty?

      value_list = Arel::Nodes::ValuesList.new(groups_with_traversal_ids)

      sql = <<~SQL
      SELECT namespace_ids.namespace_id, custom_permissions.permissions
        FROM (#{value_list.to_sql}) AS namespace_ids (namespace_id, namespace_ids),
        LATERAL (
          #{union_query}
        ) AS custom_permissions
      SQL

      grouped_by_group = ApplicationRecord.connection.select_all(sql).to_a.group_by do |h|
        h['namespace_id']
      end

      log_statistics(group_ids)

      grouped_by_group.transform_values do |values|
        group_permissions = values.map do |value|
          Gitlab::Json.parse(value['permissions']).select { |_, v| v }
        end

        group_permissions.inject(&:merge).keys.map(&:to_sym) & enabled_group_permissions
      end
    end

    def union_query
      union_queries = []

      member = Member.select('member_roles.permissions').with_user(user)

      group_member = member
        .joins(:member_role)
        .where(source_type: 'Namespace')
        .where('members.source_id IN (SELECT UNNEST(namespace_ids) as ids)')
        .to_sql

      if custom_role_for_group_link_enabled?
        group_link_join = member
          .joins('JOIN group_group_links ON members.source_id = group_group_links.shared_with_group_id')
          .where('group_group_links.shared_group_id IN (SELECT UNNEST(namespace_ids) as ids)')

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

      union_queries.push(group_member)

      union_queries.join(" UNION ALL ")
    end

    def resource_key
      "member_roles_in_groups:user:#{user.id}"
    end

    def enabled_group_permissions
      MemberRole.all_customizable_group_permissions
        .filter { |permission| ::MemberRole.permission_enabled?(permission, user) }
    end
    strong_memoize_attr :enabled_group_permissions

    def custom_role_for_group_link_enabled?
      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        group_relation.any? do |group|
          ::Feature.enabled?(:assign_custom_roles_to_group_links_saas, group.root_ancestor)
        end
      else
        ::Feature.enabled?(:assign_custom_roles_to_group_links_sm, :instance)
      end
    end

    def log_statistics(group_ids)
      ::Gitlab::AppLogger.info(
        class: self.class.name,
        user_id: user.id,
        groups_count: group_ids.length,
        group_ids: group_ids.first(10)
      )
    end
  end
end
