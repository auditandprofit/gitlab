# frozen_string_literal: true

module EE
  module ContainerRegistry
    module Event
      extend ::Gitlab::Utils::Override

      override :handle!
      def handle!
        super
        geo_handle_after_update!
        publish_internal_event
      end

      private

      def publish_internal_event
        return unless action_push?
        return unless project

        push_event = ::ContainerRegistry::ImagePushedEvent.new(
          data: { project_id: project.id, image: image_path }).tap do |event|
          event.project = project
        end

        ::Gitlab::EventStore.publish(push_event)
      end

      def image_path
        "#{::Gitlab.config.registry.host_port}/#{event.dig('target', 'repository')}:#{event.dig('target', 'tag')}"
      end

      def geo_handle_after_update!
        return unless media_type_manifest? || target_tag?
        return unless container_repository_exists?

        container_repository = find_container_repository!
        container_repository.geo_handle_after_update
      end

      def media_type_manifest?
        event.dig('target', 'mediaType')&.include?('manifest')
      end

      def find_container_repository!
        ::ContainerRepository.find_by_path!(container_registry_path)
      end
    end
  end
end
