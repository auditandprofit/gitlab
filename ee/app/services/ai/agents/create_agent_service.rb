# frozen_string_literal: true

module Ai
  module Agents
    class CreateAgentService < BaseService
      def initialize(project, name, prompt)
        @project = project
        @name = name
        @prompt = prompt
        @version = nil
      end

      def execute
        @agent = Ai::Agent.new(
          project: @project,
          name: @name
        )

        @agent.versions = [Ai::Agents::CreateAgentVersionService.new(@agent, @prompt).build]

        @agent.save

        @agent
      end
    end
  end
end
