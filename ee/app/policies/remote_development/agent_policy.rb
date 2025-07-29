# frozen_string_literal: true

module RemoteDevelopment
  # noinspection RubyResolve -- https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-32336
  module AgentPolicy
    extend ActiveSupport::Concern

    included do
      condition(:organization_workspaces_authorized_agent, score: 10) do
        organization = @subject.project.organization
        organization.user?(@user) && @subject.unversioned_latest_workspaces_agent_config&.enabled &&
          @subject.organization_cluster_agent_mapping&.organization_id == organization.id
      end

      rule { admin_agent }.policy do
        enable :admin_organization_cluster_agent_mapping
        enable :admin_namespace_cluster_agent_mapping
      end

      rule { can?(:maintainer_access) }.enable :read_namespace_cluster_agent_mapping

      rule { organization_workspaces_authorized_agent }.policy do
        enable :read_cluster_agent
        enable :create_workspace
      end
    end
  end
end
