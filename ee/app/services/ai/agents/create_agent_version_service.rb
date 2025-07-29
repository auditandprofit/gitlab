# frozen_string_literal: true

module Ai
  module Agents
    class CreateAgentVersionService < BaseService
      DEFAULT_MODEL = 'default'

      def initialize(agent, prompt)
        @agent = agent
        @prompt = prompt
      end

      def build
        Ai::AgentVersion.new(
          project: @agent.project,
          agent: @agent,
          prompt: @prompt,
          model: DEFAULT_MODEL # todo model will be set later
        )
      end

      def execute
        @agent_version = build

        @agent_version.save

        @agent_version
      end
    end
  end
end
