# frozen_string_literal: true

module Gitlab
  module Llm
    class Logger < ::Gitlab::JsonLogger
      def self.file_name_noext
        'llm'
      end

      def self.log_level
        Gitlab::Utils.to_boolean(ENV['LLM_DEBUG']) ? ::Logger::DEBUG : ::Logger::INFO
      end

      def conditional_info(user, message:, klass:, event_name:, ai_component:, **options)
        if Feature.enabled?(:expanded_ai_logging, user)
          info(message: message, klass: klass, event_name: event_name, ai_component: ai_component, **options)
        else
          info(message: message, klass: klass, event_name: event_name, ai_component: ai_component)
        end
      end

      def info(message:, klass:, event_name:, ai_component:, **options)
        options.merge!(message: message, class: klass, ai_event_name: event_name, ai_component: ai_component)
        super(options)
      end

      def error(message:, klass:, event_name:, ai_component:, **options)
        options.merge!(message: message, class: klass, ai_event_name: event_name, ai_component: ai_component)
        super(options)
      end

      def debug(message:, klass:, event_name:, ai_component:, **options)
        options.merge!(message: message, class: klass, ai_event_name: event_name, ai_component: ai_component)
        super(options)
      end

      def warn(message:, klass:, event_name:, ai_component:, **options)
        options.merge!(message: message, class: klass, ai_event_name: event_name, ai_component: ai_component)
        super(options)
      end
    end
  end
end
