# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      class Base
        include Gitlab::Utils::StrongMemoize
        include ::Gitlab::Llm::Concerns::Logger

        # AI provider-specific limits are applied to requests/responses. To not
        # rely only on third-party limits and assure that cache usage can't be
        # exhausted by users by sending huge texts/responses, we apply also
        # safeguard limit on maximum size of cached response. 1 token ~= 4 chars
        # in English, limit is typically ~4100 -> so 20000 char limit should be
        # sufficient.
        MAX_TEXT_LIMIT = 20_000

        def initialize(user, agent_version_id = nil, thread = nil, thread_fallback: true)
          if thread.nil?
            log_error(
              message: 'thread absent',
              event_name: 'thread_absent',
              ai_component: 'duo_chat'
            )
          end

          @thread = thread
          @agent_version_id = agent_version_id
          @user = user
          @thread_fallback = thread_fallback
        end

        def add(message)
          raise NotImplementedError
        end

        def messages
          raise NotImplementedError
        end

        def clear!
          raise NotImplementedError
        end

        private

        attr_reader :user, :agent_version_id, :thread
      end
    end
  end
end
