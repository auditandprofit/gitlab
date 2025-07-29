# frozen_string_literal: true

module Types
  module Ai
    class DescriptionComposerInputType < BaseMethodInputType
      graphql_name 'AiDescriptionComposerInput'

      argument :source_project_id, ::GraphQL::Types::ID,
        required: false,
        description: 'ID of the project where the changes are from.'

      argument :source_branch, ::GraphQL::Types::String,
        required: false,
        description: 'Source branch of the changes.'

      argument :target_branch, ::GraphQL::Types::String,
        required: false,
        description: 'Target branch of where the changes will be merged into.'

      argument :description, GraphQL::Types::String,
        required: true,
        description: 'Current description.'

      argument :title, GraphQL::Types::String,
        required: true,
        description: 'Current merge request title.'

      argument :user_prompt, GraphQL::Types::String,
        required: true,
        description: 'Prompt from user.'

      argument :previous_response, GraphQL::Types::String,
        required: false,
        description: <<~DESC
          Previously AI-generated description content used for context in iterative refinements or follow-up prompts.
        DESC
    end
  end
end
