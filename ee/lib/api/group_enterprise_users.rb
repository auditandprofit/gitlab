# frozen_string_literal: true

module API
  class GroupEnterpriseUsers < ::API::Base
    include PaginationParams

    feature_category :user_management

    helpers Gitlab::InternalEventsTracking

    helpers do
      def track_get_group_enterprise_users_api
        track_internal_event(
          'use_get_group_enterprise_users_api',
          user: current_user,
          namespace: user_group
        )
      end
    end

    before do
      authenticate!
      bad_request!('Must be a top-level group') unless user_group.root?
      authorize! :owner_access, user_group
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
    end

    resource :groups, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a list of enterprise users of the group' do
        success ::API::Entities::UserPublic
        is_array true
      end
      params do
        optional :username, type: String, desc: 'Return single user with a specific username.'
        optional :search, type: String, desc: 'Search users by name, email, username.'
        optional :active, type: Grape::API::Boolean, default: false, desc: 'Return only active users.'
        optional :blocked, type: Grape::API::Boolean, default: false, desc: 'Return only blocked users.'
        optional :created_after, type: DateTime, desc: 'Return users created after the specified time.'
        optional :created_before, type: DateTime, desc: 'Return users created before the specified time.'
        optional(
          :two_factor,
          type: String,
          desc: 'Filter users by two-factor authentication (2FA). ' \
            'Filter values are `enabled` or `disabled`. By default it returns all users.'
        )

        use :pagination
      end
      get ':id/enterprise_users' do
        finder = ::Authn::EnterpriseUsersFinder.new(
          current_user,
          declared_params.merge(enterprise_group: user_group))

        users = finder.execute.preload(:identities, :group_scim_identities, :instance_scim_identities) # rubocop: disable CodeReuse/ActiveRecord -- preload

        track_get_group_enterprise_users_api

        present paginate(users), with: ::API::Entities::UserPublic
      end

      desc 'Get a single enterprise user of the group' do
        success ::API::Entities::UserPublic
      end
      params do
        requires :user_id, type: Integer, desc: 'ID of user account.'
      end
      get ":id/enterprise_users/:user_id" do
        user = user_group.enterprise_users.find(declared_params[:user_id])

        present user, with: ::API::Entities::UserPublic
      end

      desc 'Disable two factor authentication for an enterprise user'
      params do
        requires :user_id, type: Integer, desc: 'ID of user account.'
      end
      patch ":id/enterprise_users/:user_id/disable_two_factor" do
        user = user_group.enterprise_users.find(declared_params[:user_id])

        result = TwoFactor::DestroyService.new(current_user, user: user, group: user_group).execute

        if result[:status] == :success
          no_content!
        else
          bad_request!(result[:message])
        end
      end
    end
  end
end
