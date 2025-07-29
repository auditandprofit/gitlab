# frozen_string_literal: true

module Ai
  module Agents
    class DestroyAgentService
      def initialize(ai_agent, user)
        @ai_agent = ai_agent
        @user = user
      end

      def execute
        @ai_agent.destroy
        success
      rescue ActiveRecord::RecordNotDestroyed => msg
        error(msg)
      end

      private

      def success
        ServiceResponse.success(message: _('AI Agent was successfully deleted'))
      end

      def error(msg)
        ServiceResponse.error(message: format(_('Failed to delete AI Agent: %{msg}'), msg: msg))
      end
    end
  end
end
