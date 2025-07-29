# frozen_string_literal: true

module Resolvers
  module Ai
    class ChatMessagesResolver < BaseResolver
      type Types::Ai::MessageType, null: false

      argument :request_ids, [GraphQL::Types::ID],
        required: false,
        description: 'Array of request IDs to fetch.'

      argument :roles, [Types::Ai::MessageRoleEnum],
        required: false,
        description: 'Array of roles to fetch.'

      argument :conversation_type, Types::Ai::Conversations::Threads::ConversationTypeEnum,
        required: false,
        description: 'Conversation type of the thread.'

      argument :thread_id,
        ::Types::GlobalIDType[::Ai::Conversation::Thread],
        required: false,
        description: 'Global Id of the existing thread.' \
          'If it is not specified, the last thread for the specified conversation_type will be retrieved.'

      argument :agent_version_id,
        ::Types::GlobalIDType[::Ai::AgentVersion],
        required: false,
        description: "Global ID of the agent to answer the chat."

      def resolve(**args)
        return [] unless current_user

        agent_version_id = args[:agent_version_id]&.model_id
        thread = find_thread(args)

        ::Gitlab::Llm::ChatStorage.new(
          current_user,
          agent_version_id,
          thread,
          thread_fallback: view_legacy_messages?(args[:conversation_type])
        ).messages_by(args)
      end

      private

      def view_legacy_messages?(conversation_type)
        conversation_type.nil? || conversation_type == 'duo_chat_legacy'
      end

      def find_thread(args)
        thread_id = args[:thread_id]&.model_id
        Gitlab::Llm::ThreadEnsurer.new(current_user, Current.organization).execute(
          thread_id: thread_id,
          conversation_type: args[:conversation_type]
        )
      rescue RuntimeError => e
        raise Gitlab::Graphql::Errors::ArgumentError, e.message
      end
    end
  end
end
