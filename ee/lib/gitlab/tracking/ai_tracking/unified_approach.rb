# frozen_string_literal: true

module Gitlab
  module Tracking
    module AiTracking
      module UnifiedApproach
        class << self
          def track_event(event_name, **context_hash)
            return unless AiTracking.registered_events.key?(event_name.to_s)

            event = build_event_model(event_name, context_hash)

            store_to_postgres(event)
            store_to_clickhouse(event)

            true
          end

          private

          def base_attributes
            %w[user timestamp event namespace_id].freeze
          end

          def build_event_model(event_name, context_hash = {})
            context_hash = context_hash.with_indifferent_access

            attributes = apply_transformations(event_name, context_hash)

            basic_attributes = context_hash.slice(*base_attributes).merge(attributes.slice(*base_attributes))
            extra_attributes = attributes.except(*base_attributes)

            ::Ai::UsageEvent.new(basic_attributes.merge(event: event_name, extras: extra_attributes))
          end

          def store_to_clickhouse(event)
            return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

            event.store_to_clickhouse
          end

          def store_to_postgres(event)
            event.store_to_pg
          end

          def apply_transformations(event_name, context_hash)
            result = {}.with_indifferent_access

            AiTracking.registered_transformations(event_name).each do |transformation|
              transformation_result = transformation.call(context_hash.merge(result))

              result.merge!(transformation_result)
            end.compact

            unless result[:namespace_id]
              guessed_namespace_id = guess_namespace_id(context_hash.merge(result))

              result[:namespace_id] = guessed_namespace_id if guessed_namespace_id
            end

            result
          end

          def guess_namespace_id(context_hash)
            related_namespace(context_hash)&.id
          end

          def related_namespace(context_hash)
            # Order matters. project should take precedence over namespace
            project = if context_hash[:project]
                        context_hash[:project]
                      elsif context_hash[:project_id]
                        ::Project.find_by_id(context_hash[:project_id])
                      end

            return project.project_namespace if project

            if context_hash[:namespace]
              context_hash[:namespace]
            elsif context_hash[:namespace_id]
              ::Namespace.find_by_id(context_hash[:namespace_id])
            end
          end
        end
      end
    end
  end
end
