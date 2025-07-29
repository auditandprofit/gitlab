# frozen_string_literal: true

module EE
  module Namespaces
    module MarkForDeletionBaseService
      extend ::Gitlab::Utils::Override

      private

      override :log_event
      def log_event
        super

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def audit_context
        {
          name: "#{resource_name}_deletion_marked",
          author: current_user,
          scope: resource,
          target: resource,
          message: "#{resource_name.titleize} marked for deletion"
        }.merge(extra_log_audit_event_context)
      end

      # Can be overridden
      def extra_log_audit_event_context
        {}
      end
    end
  end
end
