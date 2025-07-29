# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class WorkspaceCreator
        include CreateConstants
        include States
        include Messages

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.create(context)
          context => {
            devfile_yaml: String => devfile_yaml,
            processed_devfile: Hash => processed_devfile,
            volume_mounts: Hash => volume_mounts,
            personal_access_token: PersonalAccessToken => personal_access_token,
            workspace_name: String => workspace_name,
            workspace_namespace: String => workspace_namespace,
            params: Hash => params,
          }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => {
            path: String => workspace_data_volume_path,
          }
          params => {
            desired_state: String => desired_state,
            project_ref: String => project_ref,
            devfile_path: String | nil => devfile_path,
            agent: Clusters::Agent => agent,
            user: User => user,
            project: Project => project,
          }
          project_dir = "#{workspace_data_volume_path}/#{project.path}"

          workspace = RemoteDevelopment::Workspace.new
          workspace.name = workspace_name
          workspace.namespace = workspace_namespace
          workspace.desired_state = desired_state
          workspace.actual_state = CREATION_REQUESTED
          # noinspection RubyResolve -- RubyMine not detecting project_ref field
          workspace.project_ref = project_ref
          workspace.devfile_path = devfile_path
          workspace.devfile = devfile_yaml
          workspace.processed_devfile = YAML.dump(processed_devfile.deep_stringify_keys)

          set_workspace_url(
            workspace: workspace,
            agent_dns_zone: agent.unversioned_latest_workspaces_agent_config.dns_zone,
            project_dir: project_dir
          )

          # associations for workspace
          workspace.user = user
          workspace.project = project
          workspace.agent = agent
          workspace.personal_access_token = personal_access_token

          workspace.save

          if workspace.errors.present?
            return Gitlab::Fp::Result.err(
              WorkspaceModelCreateFailed.new({ errors: workspace.errors, context: context })
            )
          end

          Gitlab::Fp::Result.ok(
            context.merge({
              workspace: workspace
            })
          )
        end

        # @param [Workspace] workspace
        # @param [String] agent_dns_zone
        # @param [String] project_dir
        # @return [void]
        def self.set_workspace_url(workspace:, agent_dns_zone:, project_dir:)
          host = "#{WORKSPACE_EDITOR_PORT}-#{workspace.name}.#{agent_dns_zone}"
          query = { folder: project_dir }.to_query

          # NOTE: Use URI builder to ensure that we are building a valid URI, then retrieve parts from it

          uri = URI::HTTPS.build(host: host, query: query)

          workspace.url_prefix = uri.hostname.gsub(".#{agent_dns_zone}", '')
          # noinspection RubyMismatchedArgumentType - RubyMine thinks this is nilable for some reason
          workspace.url_query_string = uri.query
        end
        private_class_method :set_workspace_url
      end
    end
  end
end
