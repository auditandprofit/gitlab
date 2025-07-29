# frozen_string_literal: true

module API
  module Scim
    class InstanceScim < ::API::Base
      feature_category :system_access

      prefix 'api/scim'
      version 'v2'
      content_type :json, 'application/scim+json'
      USER_ID_REQUIREMENTS = { id: /.+/ }.freeze

      helpers ::EE::API::Helpers::ScimPagination
      helpers ::API::Helpers::ScimHelpers

      helpers do
        def check_access!
          token = Doorkeeper::OAuth::Token.from_request(
            current_request,
            *Doorkeeper.configuration.access_token_methods
          )
          unauthorized! unless token && ScimOauthAccessToken.token_matches_for_instance?(token)
        end

        def check_instance_requirements!
          not_found! if Gitlab.com?

          # This is only for self-managed, we have only one organization
          ::Current.organization = ::Organizations::Organization.first
          check_instance_saml_configured
          not_found! unless ::License.feature_available?(:instance_level_scim)
        end

        def find_user_identity(extern_uid)
          ScimIdentity.for_instance.with_extern_uid(extern_uid).first
        end

        def patch_deprovision(identity)
          ::EE::Gitlab::Scim::DeprovisioningService.new(identity).execute

          true
        rescue StandardError => e
          logger.error(
            identity: identity,
            error: e.class.name,
            message: e.message,
            source: "#{__FILE__}:#{__LINE__}"
          )
          scim_error!(message: e.message)
        end

        def reprovision(identity)
          ::EE::Gitlab::Scim::ReprovisioningService.new(identity).execute

          true
        rescue StandardError => e
          logger.error(
            identity: identity,
            error: e.class.name,
            message: e.message,
            source: "#{__FILE__}:#{__LINE__}"
          )
          scim_error!(message: e.message)
        end
      end

      namespace 'application' do
        before { check_access! }

        resource :Users do
          before { check_instance_requirements! }

          desc 'Get SCIM users' do
            success ::EE::API::Entities::Scim::Users
          end

          get do
            results = ScimFinder.new.search(params)
            response_page = scim_paginate(results)

            status :ok
            result_set = {
              resources: response_page,
              total_results: results.count,
              items_per_page: per_page(params[:count]),
              start_index: params[:startIndex]
            }
            present result_set, with: ::EE::API::Entities::Scim::Users
          rescue ScimFinder::UnsupportedFilter
            scim_error!(message: 'Unsupported Filter')
          end

          desc 'Get a SCIM user' do
            success ::EE::API::Entities::Scim::Users
          end

          get ':id', requirements: USER_ID_REQUIREMENTS do
            identity = ScimIdentity.with_extern_uid(params[:id]).first
            scim_not_found!(message: "Resource #{params[:id]} not found") unless identity

            status 200

            present identity, with: ::EE::API::Entities::Scim::User
          end

          desc 'Create a SCIM user' do
            success ::EE::API::Entities::Scim::Users
          end

          post do
            parser = ::EE::Gitlab::Scim::ParamsParser.new(params)
            result = ::EE::Gitlab::Scim::ProvisioningService.new(
              parser.post_params.merge(organization_id: ::Current.organization.id)
            ).execute

            case result.status
            when :success
              status 201

              present result.identity, with: ::EE::API::Entities::Scim::User
            when :conflict
              scim_conflict!(
                message: "Error saving user with #{sanitize_request_parameters(params).inspect}: #{result.message}"
              )
            when :error
              scim_error!(
                message: [
                  "Error saving user with #{sanitize_request_parameters(params).inspect}",
                  result.message
                ].compact.join(": ")
              )
            end
          end

          desc 'Updates a SCIM user'

          patch ':id', requirements: USER_ID_REQUIREMENTS do
            identity = find_user_identity(params[:id])
            scim_not_found!(message: "Resource #{params[:id]} not found") unless identity
            updated = update_scim_user(identity)

            if updated
              no_content!
            else
              scim_error!(
                message: "Error updating #{identity.user.name} with #{sanitize_request_parameters(params).inspect}"
              )
            end
          end

          desc 'Removes a SCIM user'

          delete ':id', requirements: USER_ID_REQUIREMENTS do
            identity = find_user_identity(params[:id])
            scim_not_found!(message: "Resource #{params[:id]} not found") unless identity
            patch_deprovision(identity)
            no_content!
          end
        end

        resource :Groups do
          helpers do
            def check_groups_feature_enabled!
              not_found! unless Feature.enabled?(:self_managed_scim_group_sync, :instance)
            end

            def find_group_link(scim_group_uid)
              # We only need one group link since they'll all have the same name and SCIM ID.
              # Multiple links can exist if the same SAML group is linked to different GitLab groups.
              group_link = SamlGroupLink.first_by_scim_group_uid(scim_group_uid)

              scim_not_found!(message: "Group #{scim_group_uid} not found") unless group_link
              group_link
            end
          end

          before do
            check_groups_feature_enabled!
            check_instance_requirements!
          end

          desc 'Create a SCIM group' do
            detail 'Associates SCIM group ID with existing SAML group link'
            success ::EE::API::Entities::Scim::Group
          end
          params do
            requires :displayName, type: String, desc: 'Name of the group as configured in GitLab'
            optional :externalId, type: String, desc: 'SCIM group ID'
          end
          post do
            result = ::EE::Gitlab::Scim::GroupSyncProvisioningService.new(
              saml_group_name: params[:displayName],
              scim_group_uid: params[:externalId] || SecureRandom.uuid
            ).execute

            case result.status
            when :success
              status 201
              present result.group_link, with: ::EE::API::Entities::Scim::Group
            when :error
              scim_error!(message: result.message)
            end
          end

          desc 'Get a SCIM group' do
            detail 'Retrieves a SCIM group by its ID'
            success ::EE::API::Entities::Scim::Group
          end
          params do
            requires :id, type: String, desc: 'The SCIM group ID'
          end
          get ':id' do
            group_link = find_group_link(params[:id])
            present group_link, with: ::EE::API::Entities::Scim::Group
          end

          desc 'Get SCIM groups' do
            success ::EE::API::Entities::Scim::Groups
          end
          params do
            optional :filter, type: String, desc: 'Filter string (e.g. displayName eq "Engineering")'
            optional :count, type: Integer, desc: 'Number of results per page'
            optional :startIndex, type: Integer, desc: 'Page offset'
            optional :excludedAttributes, type: String, desc: 'Comma-separated list of attributes to exclude'
          end
          get do
            results = Authn::ScimGroupFinder.new.search(params)
            response_page = scim_paginate(results)

            excluded_attributes = (params[:excludedAttributes] || '').split(',').map(&:strip)

            result_set = {
              resources: response_page,
              total_results: results.count,
              items_per_page: per_page(params[:count]),
              start_index: params[:startIndex]
            }

            status :ok
            present result_set, with: ::EE::API::Entities::Scim::Groups, excluded_attributes: excluded_attributes
          rescue Authn::ScimGroupFinder::UnsupportedFilter
            scim_error!(message: 'Unsupported Filter')
          end

          desc 'Update a SCIM group'
          params do
            requires :id, type: String, desc: 'The SCIM group ID'
            requires :schemas, type: Array, desc: 'SCIM schemas'
            requires :Operations, type: Array, desc: 'Operations to perform' do
              requires :op, type: String,
                values: { value: ->(v) { %w[add remove].include?(v.to_s.downcase) } },
                desc: 'Operation type'
              optional :path, type: String, desc: 'Path to modify'
              optional :value, types: [Array, String, Hash], desc: 'Value for the operation'
            end
          end
          patch ':id' do
            saml_group_links = SamlGroupLink.by_scim_group_uid(params[:id])
            scim_not_found!(message: "Group #{params[:id]} not found") unless saml_group_links.exists?

            ::EE::Gitlab::Scim::GroupSyncPatchService.new(
              scim_group_uid: params[:id],
              operations: params[:Operations]
            ).execute

            no_content!
          end

          desc 'Replace a SCIM group'
          params do
            requires :id, type: String, desc: 'The SCIM group ID'
            requires :schemas, type: Array, desc: 'SCIM schemas'
            requires :displayName, type: String, desc: 'Group display name'
            optional :members, type: Array, desc: 'Group members'
          end
          put ':id' do
            saml_group_links = SamlGroupLink.by_scim_group_uid(params[:id])
            scim_not_found!(message: "Group #{params[:id]} not found") unless saml_group_links.exists?

            ::EE::Gitlab::Scim::GroupSyncPutService.new(
              scim_group_uid: params[:id],
              members: params[:members] || [],
              display_name: params[:displayName]
            ).execute

            present saml_group_links.first, with: ::EE::API::Entities::Scim::Group, excluded_attributes: ['members']
          end

          desc 'Delete a SCIM group'
          params do
            requires :id, type: String, desc: 'The SCIM group ID'
          end
          delete ':id' do
            saml_group_links = SamlGroupLink.by_scim_group_uid(params[:id])
            scim_not_found!(message: "Group #{params[:id]} not found") unless saml_group_links.exists?

            result = ::EE::Gitlab::Scim::GroupSyncDeletionService.new(scim_group_uid: params[:id]).execute
            scim_error!(message: result.message) if result.error?

            no_content!
          end
        end
      end
    end
  end
end
