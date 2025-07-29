# frozen_string_literal: true

module EE
  module TreeHelper
    extend ::Gitlab::Utils::Override

    override :vue_tree_header_app_data
    def vue_tree_header_app_data(project, repository, ref, pipeline)
      super.merge({
        kerberos_url: alternative_kerberos_url? ? project.kerberos_url_to_repo : ''
      }.merge(vue_tree_workspace_data))
    end

    override :vue_file_list_data
    def vue_file_list_data(project, ref)
      super.merge({
        path_locks_available: project.feature_available?(:file_locks).to_s,
        path_locks_toggle: toggle_project_path_locks_path(project),
        resource_id: project.to_global_id,
        user_id: current_user.present? ? current_user.to_global_id : '',
        explain_code_available: ::Gitlab::Llm::TanukiBot.enabled_for?(user: current_user, container: project).to_s
      })
    end

    override :web_ide_button_data
    def web_ide_button_data(options = {})
      super.merge({
        project_id: project_to_use.id
      }.merge(vue_tree_workspace_data))
    end
  end
end
