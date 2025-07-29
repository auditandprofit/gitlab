# frozen_string_literal: true

module RemoteDevelopment
  # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-25400
  class WorkspacePolicy < BasePolicy
    condition(:can_access_workspaces_feature) { can?(:access_workspaces_feature, :global) }
    condition(:can_admin_cluster_agent_for_workspace) { can?(:admin_cluster, workspace.agent) }
    condition(:can_admin_owned_workspace) { workspace_owner? && has_developer_access_to_workspace_project? }

    rule { ~can_access_workspaces_feature }.policy do
      prevent :read_workspace
      prevent :update_workspace
    end

    rule { admin }.enable :read_workspace
    rule { admin }.enable :update_workspace

    rule { can_admin_owned_workspace }.enable :read_workspace
    rule { can_admin_owned_workspace }.enable :update_workspace

    rule { can_admin_cluster_agent_for_workspace }.enable :read_workspace
    rule { can_admin_cluster_agent_for_workspace }.enable :update_workspace

    private

    # @return [RemoteDevelopment::Workspace]
    def workspace
      subject
    end

    # @return [Boolean]
    def workspace_owner?
      user&.id == workspace.user_id
    end

    # @return [Boolean]
    def has_developer_access_to_workspace_project?
      can?(:developer_access, workspace.project)
    end
  end
end
