# frozen_string_literal: true

module Gitlab
  class GitAuditEvent # rubocop:disable Gitlab/NamespacedClass
    attr_reader :project, :user, :author

    def initialize(player, project)
      @project = project
      @author = player.is_a?(::API::Support::GitAccessActor) ? player.deploy_key_or_user : player
      @user = player.is_a?(::API::Support::GitAccessActor) ? player.user : player
    end

    def enabled?
      return false if user.blank? || project.blank?

      ::Feature.enabled?(:log_git_streaming_audit_events, project)
    end

    def send_audit_event(message)
      return if user.blank? || project.blank?

      ip_address = message.delete(:ip_address) if message.is_a?(Hash)

      audit_context = {
        name: 'repository_git_operation',
        stream_only: true,
        author: author,
        scope: project,
        target: project,
        message: message
      }

      audit_context[:ip_address] = ip_address if ip_address

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end
  end
end
