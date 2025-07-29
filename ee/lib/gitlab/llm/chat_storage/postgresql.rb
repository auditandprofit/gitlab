# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      class Postgresql < Base
        DEFAULT_CONVERSATION_TYPE = :duo_chat_legacy
        MAX_MESSAGES = 50

        def add(message)
          # Message is stored only partially. Some data might be missing after reloading from storage.
          data = message.to_h.slice(*%w[role referer_url])

          extras = message.extras
          if message.additional_context.present?
            extras ||= {}
            extras['additional_context'] = message.additional_context.to_a
          end

          data['extras'] = extras.to_json if extras
          data['content'] = message.content[0, MAX_TEXT_LIMIT] if message.content
          data['message_xid'] = message.id if message.id
          data['error_details'] = message.errors.to_json if message.errors
          data['request_xid'] = message.request_id if message.request_id

          data.compact!

          result = current_thread.messages.create!(**data)
          current_thread.update_column(:last_updated_at, Time.current)
          clear_memoization(:messages)

          result
        end

        def messages
          return [] unless current_thread

          current_thread.messages.recent(MAX_MESSAGES)
        end
        strong_memoize_attr :messages

        def clear!
          @current_thread = current_thread.to_new_thread!
          clear_memoization(:messages)
        end

        def current_thread
          @current_thread ||= thread
          @current_thread ||= find_default_thread || create_default_thread if @thread_fallback
        end

        private

        def find_default_thread
          user.ai_conversation_threads.for_conversation_type(DEFAULT_CONVERSATION_TYPE).last
        end

        def create_default_thread
          user.ai_conversation_threads.create!(conversation_type: DEFAULT_CONVERSATION_TYPE)
        end
      end
    end
  end
end
