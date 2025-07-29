# frozen_string_literal: true

module EE
  module BlobHelper
    extend ::Gitlab::Utils::Override

    override :vue_blob_header_app_data
    def vue_blob_header_app_data(project, blob, ref)
      super.merge(vue_blob_workspace_data)
    end

    override :vue_blob_app_data
    def show_duo_workflow_action?(blob)
      return false unless current_user.present?
      return false unless ::Feature.enabled?(:duo_workflow_in_ci, current_user)

      ::Gitlab::FileDetector.type_of(blob.name) == :jenkinsfile && ::Ai::DuoWorkflow.enabled?
    end

    def vue_blob_app_data(project, blob, ref)
      super.merge({
        explain_code_available: ::Gitlab::Llm::TanukiBot.enabled_for?(user: current_user, container: project).to_s
      }.merge(vue_blob_workspace_data))
    end
  end
end
