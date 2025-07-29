# frozen_string_literal: true

module Ai
  module Agents
    class UpdateAgentService < BaseService
      def initialize(agent, name, prompt)
        @agent = agent
        @name = name
        @prompt = prompt
      end

      def execute
        Ai::Agent.transaction do
          @agent.name = @name unless @name.nil?
          @agent.latest_version.update(prompt: @prompt) unless @prompt.nil?
          @agent.save # this method doesn't raise if it fails so that we can show vailidation errors to the user
        end

        @agent
      end
    end
  end
end
