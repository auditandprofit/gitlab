# frozen_string_literal: true

module SecretsHelper
  def project_secrets_app_data(project)
    {
      project_path: project.full_path,
      project_id: project.id,
      base_path: project_secrets_path(project)
    }
  end
end
