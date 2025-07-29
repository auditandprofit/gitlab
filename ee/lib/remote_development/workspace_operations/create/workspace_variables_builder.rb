# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class WorkspaceVariablesBuilder
        include CreateConstants
        include Files
        include Enums::WorkspaceVariable

        # @param [String] name
        # @param [String] dns_zone
        # @param [String] personal_access_token_value
        # @param [String] user_name
        # @param [String] user_email
        # @param [Integer] workspace_id
        # @param [Integer] workspace_actual_state
        # @param [Hash] vscode_extension_marketplace
        # @param [Array<Hash>] variables
        # @return [Array<Hash>]
        def self.build(
          name:, dns_zone:, personal_access_token_value:, user_name:, user_email:, workspace_id:,
          vscode_extension_marketplace:, variables:
        )
          vscode_extension_marketplace => {
            service_url: String => vscode_extension_marketplace_service_url,
            item_url: String => vscode_extension_marketplace_item_url,
            resource_url_template: String => vscode_extension_marketplace_resource_url_template,
          }

          internal_variables = [

            #-------------------------------------------------------------------
            # The directory to which logs related to the creation and management of the workspace are written.
            # For example, logs from the poststart events.
            {
              key: "GL_WORKSPACE_LOGS_DIR",
              value: WORKSPACE_LOGS_DIR,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            #-------------------------------------------------------------------
            # The user's workspace-specific personal access token which is injected into the workspace, and used for
            # authentication. For example, in the credential.helper script below.
            {
              key: TOKEN_FILE_NAME,
              value: personal_access_token_value,
              variable_type: FILE_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GL_TOKEN_FILE_PATH",
              value: TOKEN_FILE_PATH,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            #-------------------------------------------------------------------

            #-------------------------------------------------------------------
            # Standard git ENV vars which configure git on the workspace. See https://git-scm.com/docs/git-config
            {
              # TODO: Move this entry to the scripts volume: https://gitlab.com/gitlab-org/gitlab/-/issues/539045
              # This script is set as the value of `credential.helper` below in `GIT_CONFIG_VALUE_0`
              key: GIT_CREDENTIAL_STORE_SCRIPT_FILE_NAME,
              value: GIT_CREDENTIAL_STORE_SCRIPT,
              variable_type: FILE_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GIT_CONFIG_COUNT",
              value: "3",
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GIT_CONFIG_KEY_0",
              value: "credential.helper",
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GIT_CONFIG_VALUE_0",
              value: GIT_CREDENTIAL_STORE_SCRIPT_FILE_PATH,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GIT_CONFIG_KEY_1",
              value: "user.name",
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GIT_CONFIG_VALUE_1",
              value: user_name,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GIT_CONFIG_KEY_2",
              value: "user.email",
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GIT_CONFIG_VALUE_2",
              value: user_email,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            #-------------------------------------------------------------------

            #-------------------------------------------------------------------
            # The GL_WORKSPACE_DOMAIN_TEMPLATE variable is used by the GitLab Development Kit (GDK) script to configure
            # the GDK in a workspce: `support/gitlab-remote-development/setup_workspace.rb`
            {
              key: "GL_WORKSPACE_DOMAIN_TEMPLATE",
              value: "${PORT}-#{name}.#{dns_zone}",
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            #-------------------------------------------------------------------

            #-------------------------------------------------------------------
            # Variables with prefix `GL_VSCODE_EXTENSION_MARKETPLACE` are used for configuring the
            # GitLab fork of VS Code which is injected into the workspace.
            {
              key: "GL_VSCODE_EXTENSION_MARKETPLACE_SERVICE_URL",
              value: vscode_extension_marketplace_service_url,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GL_VSCODE_EXTENSION_MARKETPLACE_ITEM_URL",
              value: vscode_extension_marketplace_item_url,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GL_VSCODE_EXTENSION_MARKETPLACE_RESOURCE_URL_TEMPLATE",
              value: vscode_extension_marketplace_resource_url_template,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            #-------------------------------------------------------------------

            #-------------------------------------------------------------------
            # Variables with prefix `GITLAB_WORKFLOW_` are used for configured GitLab Workflow extension for VS Code
            {
              key: "GITLAB_WORKFLOW_INSTANCE_URL",
              value: Gitlab::Routing.url_helpers.root_url,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            },
            {
              key: "GITLAB_WORKFLOW_TOKEN_FILE",
              value: TOKEN_FILE_PATH,
              variable_type: ENVIRONMENT_TYPE,
              workspace_id: workspace_id
            }
            #-------------------------------------------------------------------
          ]

          user_provided_variables = variables.map do |variable|
            {
              key: variable.fetch(:key),
              value: variable.fetch(:value),
              variable_type: variable.fetch(:type),
              user_provided: true,
              workspace_id: workspace_id
            }
          end

          internal_variables + user_provided_variables
        end
      end
    end
  end
end
