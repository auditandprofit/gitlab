# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class EnablementCheckService
      def initialize(project:, current_user:)
        @project = project
        @current_user = current_user
      end

      def execute
        return unless Ability.allowed?(@current_user, :read_project, @project)

        enabled = Ability.allowed?(@current_user, :duo_workflow, @project)
        checks = [
          {
            name: :feature_flag,
            value: ::Feature.enabled?(:duo_workflow, @current_user),
            message: _("duo_workflow feature flag must be enabled.")
          }, {
            name: :duo_features_enabled,
            value: @project.duo_features_enabled,
            message: _("Project must have GitLab Duo features enabled.")
          }, {
            name: :developer_access,
            value: Ability.allowed?(@current_user, :developer_access, @project),
            message: _("User must have developer access to the project.")
          }, {
            name: :feature_available,
            value: ::Gitlab::Llm::StageCheck.available?(@project,
              :duo_workflow) && @current_user&.allowed_to_use?(:duo_agent_platform),
            message: _("duo_workflow licensed feature must be available for the project and experimental " \
              "features must be enabled.")
          }
        ]

        {
          enabled: enabled,
          checks: checks
        }
      end
    end
  end
end
