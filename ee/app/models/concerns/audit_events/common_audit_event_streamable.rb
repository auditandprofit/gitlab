# frozen_string_literal: true

module AuditEvents
  module CommonAuditEventStreamable
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    def stream_to_external_destinations(use_json: false, event_name: 'audit_operation')
      return unless can_stream_to_external_destination?(event_name)

      perform_params = if use_json
                         [event_name, nil, streaming_json]
                       else
                         [event_name, id, nil, self.class.name]
                       end

      ::AuditEvents::AuditEventStreamingWorker.perform_async(*perform_params)
    end

    def entity_is_group_or_project?
      %w[Group Project].include?(entity_type)
    end

    def as_json(options = {})
      super.tap do |json|
        json['ip_address'] = ip_address.to_s
        json['entity_id'] = entity_id if entity_id.present?
        json['entity_type'] = entity_type if entity_type.present?
      end
    end

    private

    def can_stream_to_external_destination?(event_name)
      return false if ::Gitlab::SilentMode.enabled?
      return false if entity.nil?
      return false unless ::Gitlab::Audit::FeatureFlags.stream_from_new_tables?(entity)

      ::AuditEvents::ExternalDestinationStreamer.new(event_name, self).streamable?
    end

    def streaming_json
      ::Gitlab::Json.generate(self, methods: [:root_group_entity_id])
    end
  end
end
