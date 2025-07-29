# frozen_string_literal: true

module Gitlab
  module Graphql
    module Representation
      class AiFeatureSetting < SimpleDelegator
        class << self
          def decorate(feature_settings, with_valid_models: false)
            return [] unless feature_settings.present?

            return feature_settings.map { |feature_setting| new(feature_setting) } unless with_valid_models

            decorate_with_valid_models(feature_settings)
          end

          def decorate_with_valid_models(feature_settings)
            indexed_self_hosted_models = ::Ai::SelfHostedModel.all.group_by(&:model)

            feature_settings.map do |feature_setting|
              compatible_llms = feature_setting.compatible_llms || []

              valid_models = compatible_llms.flat_map do |model|
                indexed_self_hosted_models[model] || []
              end

              valid_models = valid_models.filter(&:ga?) unless beta_models_enabled?

              new(feature_setting, valid_models: valid_models.sort_by(&:name))
            end
          end

          def beta_models_enabled?
            ::Ai::TestingTermsAcceptance.has_accepted?
          end
        end

        attr_accessor :valid_models

        def initialize(feature_setting, valid_models: [])
          @feature_setting = feature_setting
          @valid_models = valid_models

          super(feature_setting)
        end
      end
    end
  end
end
