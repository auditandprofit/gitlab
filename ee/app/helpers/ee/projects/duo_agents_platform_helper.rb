# frozen_string_literal: true

module EE
  module Projects
    module DuoAgentsPlatformHelper
      def duo_agents_platform_data(project)
        {
          agents_platform_base_route: project_automate_path(project),
          duo_agents_invoke_path: api_v4_ai_duo_workflows_workflows_path,
          project_id: project.id,
          project_path: project.full_path,
          empty_state_illustration_path: image_path('illustrations/empty-state/empty-pipeline-md.svg')
        }
      end
    end
  end
end
