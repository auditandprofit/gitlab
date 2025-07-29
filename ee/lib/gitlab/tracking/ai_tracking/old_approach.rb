# frozen_string_literal: true

module Gitlab
  module Tracking
    module AiTracking
      # This module will be removed completely after we migrate to new approach described
      # in https://gitlab.com/gitlab-org/gitlab/-/issues/538343
      module OldApproach
        POSSIBLE_MODELS = [::Ai::CodeSuggestionEvent, ::Ai::DuoChatEvent, ::Ai::TroubleshootJobEvent].freeze

        class << self
          def track_event(event_name, **context_hash)
            event = build_event_model(event_name, context_hash)

            return unless event

            store_to_clickhouse(event)
            store_to_postgres(event)

            true
          end

          private

          def build_event_model(event_name, context_hash = {})
            matched_model = POSSIBLE_MODELS.detect { |model| model.related_event?(event_name) }
            return unless matched_model

            context_hash = context_hash.with_indifferent_access

            context_hash[:event] = event_name
            context_hash[:project] ||= ::Project.find(context_hash[:project_id]) if context_hash[:project_id]
            context_hash[:namespace] ||= ::Namespace.find(context_hash[:namespace_id]) if context_hash[:namespace_id]

            context_hash[:namespace_path] ||= build_traversal_path(context_hash)

            basic_attributes = context_hash.slice(*matched_model.permitted_attributes)
            payload_attributes = context_hash.slice(*matched_model.payload_attributes)

            matched_model.new(basic_attributes.merge(payload: payload_attributes))
          end

          def store_to_clickhouse(event)
            return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

            event.store_to_clickhouse
          end

          def store_to_postgres(event)
            return unless event.respond_to?(:store_to_pg)

            event.store_to_pg
          end

          def build_traversal_path(context_hash)
            context_hash[:project]&.project_namespace&.traversal_path || context_hash[:namespace]&.traversal_path
          end
        end
      end
    end
  end
end
