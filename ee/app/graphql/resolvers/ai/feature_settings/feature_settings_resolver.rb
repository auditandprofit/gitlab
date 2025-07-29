# frozen_string_literal: true

module Resolvers
  module Ai
    module FeatureSettings
      class FeatureSettingsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type ::Types::Ai::FeatureSettings::FeatureSettingType.connection_type, null: false

        argument :self_hosted_model_id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: false,
          description: 'Global ID of the self-hosted model.'

        def resolve(self_hosted_model_id: nil)
          return unless Ability.allowed?(current_user, :manage_self_hosted_models_settings)

          feature_settings = get_feature_settings(self_hosted_model_id)

          ::Gitlab::Graphql::Representation::AiFeatureSetting
            .decorate(feature_settings, with_valid_models: valid_models_field_requested?)
        end

        private

        def get_feature_settings(self_hosted_model_id)
          ::Ai::FeatureSettings::FeatureSettingFinder.new(self_hosted_model_id: self_hosted_model_id).execute
        end

        def valid_models_field_requested?
          context.query.sanitized_query_string.include?('validModels')
        end
      end
    end
  end
end
