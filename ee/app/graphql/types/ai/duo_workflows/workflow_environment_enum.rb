# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowEnvironmentEnum < BaseEnum
        graphql_name 'WorkflowEnvironment'
        description 'The environment of a workflow.'

        ::Ai::DuoWorkflows::Workflow.environments.each_key do |mode|
          value mode.upcase, value: mode, description: "#{mode.titleize} environment"
        end
      end
    end
  end
end
