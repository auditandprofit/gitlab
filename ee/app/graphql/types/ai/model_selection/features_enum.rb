# frozen_string_literal: true

module Types
  module Ai
    module ModelSelection
      class FeaturesEnum < BaseEnum
        graphql_name 'AiModelSelectionFeatures'
        description 'AI features that can be configured through the Model Selection feature settings.'

        ::Ai::ModelSelection::FeaturesConfigurable::FEATURES.each_key do |feature_key|
          feature_title = feature_key == :duo_chat ? feature_key.to_s.titleize : feature_key.to_s.humanize.singularize
          value feature_key.upcase, description: "#{feature_title} feature setting", value: feature_key
        end
      end
    end
  end
end
