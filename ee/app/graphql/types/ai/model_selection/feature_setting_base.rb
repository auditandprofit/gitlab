# frozen_string_literal: true

module Types
  module Ai
    module ModelSelection
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
      class FeatureSettingBase < ::Types::BaseObject
        graphql_name 'AiModelSelectionFeatureSettingBase'

        field :feature, String, null: false, description: 'Identifier for the AI feature.'

        field :title, String, null: true, description: 'Displayed AI feature name.'

        field :main_feature, String, null: true, description: 'Displayed name of the main feature.'

        field :selected_model, ::Types::Ai::ModelSelection::OfferedModelType,
          null: true,
          description: 'Identifier of the current model selected.'

        field :default_model, ::Types::Ai::ModelSelection::OfferedModelType,
          null: true,
          description: 'LLMs Compatible with the feature.'

        field :selectable_models, [Types::Ai::ModelSelection::OfferedModelType],
          null: false,
          description: 'LLMs Compatible with the feature.'

        def selected_model
          return unless object.offered_model_ref

          {
            ref: object.offered_model_ref,
            name: object.offered_model_name
          }
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
