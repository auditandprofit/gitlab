# frozen_string_literal: true

module Ai
  module Agents
    class AgentFinder
      def initialize(project)
        @project = project
      end

      def execute
        ::Ai::Agent
          .for_project(@project).including_project
      end
    end
  end
end
