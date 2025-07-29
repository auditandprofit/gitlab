# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class CreatorBootstrapper
        include CreateConstants

        RANDOM_STRING_LENGTH = 6

        # @param [Hash] context
        # @return [Hash]
        def self.bootstrap(context)
          # Skip type checking so we can use fast_spec_helper in the unit test spec
          context => {
            user: user,
            params: {
              agent: agent
            }
          }

          random_string = SecureRandom.alphanumeric(RANDOM_STRING_LENGTH).downcase
          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409774
          #       We can come maybe come up with a better/cooler way to get a unique name, for now this works
          workspace_name = "workspace-#{agent.id}-#{user.id}-#{random_string}"
          shared_namespace = agent.unversioned_latest_workspaces_agent_config.shared_namespace

          workspace_namespace =
            # NOTE: Empty string is a "magic value" that indicates default per-workspace namespaces should be used.
            case shared_namespace
            when ""
              # Use a unique namespace, with one workspace per namespace
              "#{NAMESPACE_PREFIX}-#{agent.id}-#{user.id}-#{random_string}"
            else
              # Use a shared namespace, with multiple workspaces in the same namespace
              shared_namespace
            end

          context.merge(
            workspace_name: workspace_name,
            workspace_namespace: workspace_namespace
          )
        end
      end
    end
  end
end
