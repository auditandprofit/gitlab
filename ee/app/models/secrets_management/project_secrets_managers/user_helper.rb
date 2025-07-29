# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    module UserHelper
      extend ActiveSupport::Concern

      # currently we are gonna set the max_group as 25, but will increase if nescessary
      MAX_GROUPS = 25

      def user_auth_mount
        [
          namespace_path,
          'user_jwt'
        ].compact.join('/')
      end

      def user_auth_role
        "project_#{project.id}"
      end

      def user_auth_type
        'jwt'
      end

      def user_auth_policies
        [
          # User policy
          user_policy_template,
          # MemberRole policy
          member_role_policy_template,
          # Group policy
          *group_policy_template,
          # Role policy
          role_policy_template
        ]
      end

      def user_policy_template
        "{{ if ne \"\" .user_id }}project_{{ .project_id }}/users/direct/user_{{ .user_id }}{{ end }}"
      end

      def member_role_policy_template
        "{{ if ne \"\" .member_role_id }}project_{{ .project_id }}/users/direct/member_role_{{ .member_role_id }}" \
          "{{ end }}"
      end

      def group_policy_template
        (0...MAX_GROUPS).map do |i|
          "{{ if gt (len .groups) #{i} }}project_{{ .project_id }}/users/direct/group_{{ index .groups #{i} }}{{ end }}"
        end
      end

      def role_policy_template
        "{{ if ne \"\" .role_id }}project_{{ .project_id }}/users/roles/{{ .role_id }}{{ end }}"
      end
    end
  end
end
