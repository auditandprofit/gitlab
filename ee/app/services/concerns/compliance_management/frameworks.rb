# frozen_string_literal: true

module ComplianceManagement
  module Frameworks
    def compliance_pipeline_configuration_available?
      return true if params[:pipeline_configuration_full_path].blank?

      can?(current_user, :admin_compliance_pipeline_configuration, framework)
    end

    def project_framework_same_namespace?(project, framework)
      project.root_ancestor&.id == framework.namespace_id
    end
  end
end
