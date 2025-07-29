# frozen_string_literal: true

module Mutations
  module Ai
    module FeatureSettings
      class Update < Base
        graphql_name 'AiFeatureSettingUpdate'
        description "Updates or creates settings for AI features."

        argument :features, [::Types::Ai::FeatureSettings::FeaturesEnum],
          required: true,
          description: 'Array of AI features being configured (for single or batch update).'

        argument :provider, ::Types::Ai::FeatureSettings::ProvidersEnum,
          required: true,
          description: 'Provider for AI setting.'

        argument :ai_self_hosted_model_id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: false,
          description: 'Global ID of the self-hosted model providing the AI setting.'

        def resolve(**args)
          check_feature_access!

          return { ai_feature_settings: [], errors: ['At least one feature is required'] } if args[:features].empty?

          upsert_args = args.dup
          upsert_args.delete(:features)

          results = args[:features].map do |feature|
            upsert_feature_setting(upsert_args.merge(feature: feature))
          end

          errors = results.select(&:error?).flat_map(&:errors)
          feature_settings = results.reject(&:error?).flat_map(&:payload)

          decorated_feature_settings = ::Gitlab::Graphql::Representation::AiFeatureSetting
            .decorate(feature_settings, with_valid_models: true)

          {
            ai_feature_settings: decorated_feature_settings,
            errors: errors
          }
        end

        private

        def upsert_feature_setting(args)
          feature_setting = find_or_initialize_object(feature: args[:feature])

          self_hosted_model_gid = args[:ai_self_hosted_model_id]
          if self_hosted_model_gid.present?
            args[:ai_self_hosted_model_id] =
              GitlabSchema.parse_gid(self_hosted_model_gid)&.model_id
          end

          ::Ai::FeatureSettings::UpdateService.new(
            feature_setting, current_user, args
          ).execute
        end

        def find_or_initialize_object(feature:)
          ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)
        end
      end
    end
  end
end
