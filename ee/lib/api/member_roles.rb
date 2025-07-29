# frozen_string_literal: true

module API
  class MemberRoles < ::API::Base
    before { authenticate! }

    feature_category :system_access

    helpers ::API::Helpers::MemberRolesHelpers

    helpers do
      include ::Gitlab::Utils::StrongMemoize

      def member_role_name
        declared_params[:name].presence || "#{Gitlab::Access.human_access(params[:base_access_level])} - custom"
      end

      def authorize_access_roles!
        return authorize_admin_member_role_on_group! if params[:id]

        authorize_admin_member_role_on_instance!
      end

      def group
        return unless params[:id]

        user_group
      end
      strong_memoize_attr :group

      def member_roles
        filter_params = group ? { parent: group } : {}

        ::MemberRoles::RolesFinder.new(current_user, filter_params).execute
      end

      params :create_role_params do
        requires 'base_access_level', type: Integer, values: Gitlab::Access.all_values,
          desc: 'Base Access Level for the configured role', documentation: { example: 10 }

        optional :name, type: String, desc: "Name for role (default: 'Custom')"
        optional :description, type: String, desc: "Description for role"

        ::MemberRole.all_customizable_permissions.each do |permission_name, permission_params|
          optional permission_name.to_s, type: Boolean, desc: permission_params[:description], default: false
        end
      end

      def deprecation_message
        docs_page = Rails.application.routes.url_helpers.help_page_url(
          'update/deprecations.md',
          anchor: 'deprecate-custom-role-creation-for-group-owners-on-self-managed'
        )

        "Group-level custom roles are deprecated on self-managed instances. " \
          "See #{docs_page}"
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
    end

    resource :groups do
      before do
        bad_request!(deprecation_message) unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      desc 'Get Member Roles for a group' do
        success EE::API::Entities::MemberRole
        is_array true
        tags %w[group_member_roles]
      end

      get ":id/member_roles" do
        get_roles
      end

      desc 'Create Member Role for a group' do
        success EE::API::Entities::MemberRole
        failure [[400, 'Bad Request'], [401, 'Unauthorized']]
        tags %w[group_member_roles]
      end

      params do
        use :create_role_params
      end

      post ":id/member_roles" do
        create_role
      end

      desc 'Delete Member Role for a group' do
        success code: 204, message: '204 No Content'
        failure [[400, 'Bad Request'], [401, 'Unauthorized'], [404, '404 Member Role Not Found']]
        tags %w[group_member_roles]
      end

      params do
        requires :member_role_id, type: Integer, desc: 'The ID of the Group-Member Role to be deleted'
      end

      delete ":id/member_roles/:member_role_id" do
        delete_role
      end
    end

    resource :member_roles do
      before do
        bad_request! if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      desc 'Get Member Roles for this GitLab instance' do
        success EE::API::Entities::MemberRole
        failure [[401, 'Unauthorized']]
        is_array true
        tags %w[member_roles]
      end

      get do
        get_roles
      end

      desc 'Create Member Role on the GitLab instance' do
        success EE::API::Entities::MemberRole
        failure [[400, 'Bad Request'], [401, 'Unauthorized']]
        tags %w[member_roles]
      end

      params do
        use :create_role_params
      end

      post do
        create_role
      end

      desc 'Delete Member Role' do
        success code: 204, message: '204 No Content'
        failure [[400, 'Bad Request'], [401, 'Unauthorized'], [404, '404 Member Role Not Found']]
        tags %w[member_roles]
      end

      params do
        requires :member_role_id, type: Integer, desc: 'ID of the member role'
      end

      delete ':member_role_id' do
        delete_role
      end
    end
  end
end
