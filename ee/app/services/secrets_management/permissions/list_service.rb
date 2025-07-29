# frozen_string_literal: true

module SecretsManagement
  module Permissions
    class ListService < BaseService
      include SecretsManagerClientHelpers
      include ErrorResponseHelper

      def execute
        return inactive_response unless project.secrets_manager&.active?

        secret_permissions = list_secret_permissions(project)

        ServiceResponse.success(payload: { secret_permissions: secret_permissions })
      end

      private

      def list_secret_permissions(project)
        permissions = []

        secrets_manager_client.list_project_policies(project_id: project.id) do |policy_data|
          policy_name = policy_data["key"]
          policy = policy_data["metadata"]

          # Skip if not a valid policy
          next unless policy_name.start_with?("project_#{project.id}/users/")

          # Extract principal information from policy name
          path_parts = policy_name.split('/')
          principal_type, principal_id = extract_principal_info_from_policy(path_parts)

          next unless principal_type && principal_id

          granted_by = nil
          # Extract permissions from the capabilities
          permissions_set = Set.new

          policy.paths.each do |path, path_obj|
            # Skip paths that don't match the project's pattern

            correct_path_exists = if project.namespace.type == "User"
                                    path.include?("user_#{project.namespace.id}/project_#{project.id}")
                                  else
                                    path.include?("group_#{project.group.id}/project_#{project.id}")
                                  end

            next unless correct_path_exists

            granted_by = path_obj.granted_by
            path_obj.capabilities.each do |capability|
              if SecretsManagement::SecretPermission::VALID_PERMISSIONS.include?(capability)
                permissions_set.add(capability)
              end
            end
          end

          # Create the permission object
          permissions << SecretsManagement::SecretPermission.new(
            project: project,
            principal_type: principal_type,
            principal_id: principal_id,
            resource_type: 'Project',
            resource_id: project.id,
            granted_by: granted_by,
            permissions: permissions_set.to_a
          )
        end

        permissions
      end

      def extract_principal_info_from_policy(path_parts)
        # path_parts structure: ["project_ID", "users", TYPE, IDENTIFIER]
        return [nil, nil] if path_parts.size < 4

        case path_parts[2]
        when 'direct'
          if path_parts[3].start_with?('user_')
            ['User', path_parts[3].sub('user_', '').to_i]
          elsif path_parts[3].start_with?('member_role_')
            ['MemberRole', path_parts[3].sub('member_role_', '').to_i]
          elsif path_parts[3].start_with?('group_')
            ['Group', path_parts[3].sub('group_', '').to_i]
          end
        when 'roles'
          role_id = path_parts[3]
          role_id ? ['Role', role_id] : [nil, nil]
        end
      end
    end
  end
end
