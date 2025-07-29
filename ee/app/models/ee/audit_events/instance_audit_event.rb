# frozen_string_literal: true

module EE
  module AuditEvents
    module InstanceAuditEvent
      include ::Gitlab::Utils::StrongMemoize
      include ::AuditEvents::CommonAuditEventStreamable

      attr_accessor :root_group_entity_id
      attr_writer :entity

      def entity
        ::Gitlab::Audit::InstanceScope.new
      end
      strong_memoize_attr :entity

      def entity_id
        nil
      end

      def entity_type
        ::Gitlab::Audit::InstanceScope.name
      end

      def present
        AuditEventPresenter.new(self)
      end

      def root_group_entity
        nil
      end
      strong_memoize_attr :root_group_entity
    end
  end
end
