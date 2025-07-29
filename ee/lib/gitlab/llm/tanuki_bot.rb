# frozen_string_literal: true

module Gitlab
  module Llm
    class TanukiBot
      def self.enabled_for?(user:, container: nil)
        return false unless chat_enabled?(user)
        return false if authorized_by_duo_core?(user)

        authorizer_response = if container
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
                              else
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user)
                              end

        authorizer_response.allowed?
      end

      def self.agentic_mode_available?(user:, project:, group:)
        return false unless Feature.enabled?(:duo_workflow_workhorse, user)

        if project.present? && project.persisted?
          user.can?(:access_duo_agentic_chat, project)
        elsif group.present? && group.persisted?
          user.can?(:access_duo_agentic_chat, group)
        else
          false
        end
      end

      def self.show_breadcrumbs_entry_point?(user:, container: nil)
        return false unless chat_enabled?(user) && container
        return false if authorized_by_duo_core?(user)

        Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user).allowed?
      end

      def self.authorized_by_duo_core?(user)
        authorization_response = user.allowed_to_use(:duo_chat)
        authorization_response.authorized_by_duo_core
      end

      def self.chat_disabled_reason(user:, container: nil)
        return unless container

        authorizer_response = Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
        return if authorizer_response.allowed?

        container.is_a?(Group) ? :group : :project
      end

      def self.chat_enabled?(user)
        return false unless user

        true
      end

      def self.resource_id
        Gitlab::ApplicationContext.current_context_attribute(:ai_resource).presence
      end

      def self.project_id
        project_path = Gitlab::ApplicationContext.current_context_attribute(:project).presence
        Project.find_by_full_path(project_path).try(:to_global_id) if project_path
      end

      def self.root_namespace_id
        namespace_path = Gitlab::ApplicationContext.current_context_attribute(:root_namespace).presence
        return unless namespace_path

        namespace = Group.find_by_full_path(namespace_path)
        return unless namespace
        return unless ::Feature.enabled?(:ai_model_switching, namespace)

        namespace.to_global_id
      end
    end
  end
end
