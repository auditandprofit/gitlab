# frozen_string_literal: true

module EE
  module AuditEvents
    module ProjectAuditEvent
      include ::Gitlab::Utils::StrongMemoize
      include ::AuditEvents::CommonAuditEventStreamable

      attr_accessor :root_group_entity_id
      attr_writer :project

      def project
        lazy_project
      end
      strong_memoize_attr :project

      def entity
        project
      end

      def entity_id
        return if entity.is_a?(::Gitlab::Audit::NullEntity)

        entity.id if entity.respond_to?(:id)
      end

      def entity_type
        "Project"
      end

      def present
        AuditEventPresenter.new(self)
      end

      def root_group_entity
        return ::Group.find_by(id: root_group_entity_id) if root_group_entity_id.present?
        return if project.nil?

        root_group_entity = project.group&.root_ancestor
        self.root_group_entity_id = root_group_entity&.id
        root_group_entity
      end
      strong_memoize_attr :root_group_entity

      private

      def lazy_project
        BatchLoader.for(project_id).batch(default_value: ::Gitlab::Audit::NullEntity.new) do |ids, loader|
          ::Project.id_in(ids).find_each { |record| loader.call(record.id, record) }
        end
      end
    end
  end
end
