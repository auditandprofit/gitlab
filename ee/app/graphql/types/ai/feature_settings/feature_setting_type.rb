# frozen_string_literal: true

module Types
  module Ai
    module FeatureSettings
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
      class FeatureSettingType < ::Types::BaseObject
        graphql_name 'AiFeatureSetting'
        description 'Duo Chat feature setting'

        field :feature, String, null: false, description: 'Identifier for the AI feature.'

        field :provider, String, null: false, description: 'Humanized name for the AI feature, e.g "Code Completion".'

        field :title, String, null: true, description: 'Displayed AI feature name.'

        field :main_feature, String, null: true, description: 'Displayed name of the main feature.'

        field :compatible_llms, [String], null: true, description: 'LLMs Compatible with the feature.'

        field :release_state, String, null: true, description: 'Current release state of the feature.'

        field :self_hosted_model,
          Types::Ai::SelfHostedModels::SelfHostedModelType,
          null: true,
          description: 'Self-hosted model selected for use with the AI feature.'

        field :valid_models,
          Types::Ai::SelfHostedModels::SelfHostedModelType.connection_type,
          null: false,
          description: 'Compatible self-hosted models for the feature.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
