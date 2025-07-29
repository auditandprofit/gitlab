# frozen_string_literal: true

module Gitlab
  module Tracking
    # rubocop:disable Gitlab/ModuleWithInstanceVariables -- it's a class level DSL. It's intended to be a module.
    module AiUsageEventsRegistryDsl
      def register(&block)
        @registered_events ||= {}.with_indifferent_access
        instance_eval(&block)
      end

      def events(names_with_ids, &event_transformation)
        names_with_ids.each do |name, id|
          guard_internal_event_existence!(name)
          guard_duplicated_event!(name, id)
          @registered_events[name] = { id: id, transformations: [] }
          transformation(name, &event_transformation)
        end
      end

      def deprecated_events(names_with_ids)
        names_with_ids.each do |name, id|
          guard_duplicated_event!(name, id)
          @registered_events[name] = { id: id, transformations: [], deprecated: true }
        end
      end

      def transformation(*names, &block)
        return unless block

        names.each do |name|
          @registered_events[name][:transformations] << block
        end
      end

      def registered_events
        return {} unless @registered_events

        @registered_events.transform_values { |options| options[:id] }
      end

      def registered_transformations(event_name)
        return [] unless @registered_events

        @registered_events[event_name]&.fetch(:transformations)
      end

      def deprecated_event?(event_name)
        return false unless @registered_events && @registered_events[event_name]

        @registered_events[event_name][:deprecated]
      end

      private

      def guard_internal_event_existence!(event_name)
        return if Gitlab::Tracking::EventDefinition.internal_event_exists?(event_name.to_s)

        raise "Event `#{event_name}` is not defined in InternalEvents"
      end

      def guard_duplicated_event!(name, id)
        raise "Event with name `#{name}` was already registered" if @registered_events[name]
        raise "Event with id `#{id}` was already registered" if @registered_events.detect { |_n, e| e[:id] == id }
      end
    end
    # rubocop:enable Gitlab/ModuleWithInstanceVariables
  end
end
