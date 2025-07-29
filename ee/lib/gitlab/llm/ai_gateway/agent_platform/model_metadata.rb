# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module AgentPlatform
        class ModelMetadata
          def initialize(feature_setting:)
            @feature_setting = feature_setting
          end

          def execute
            return unless feature_flag_enabled?

            model_metadata = ::Gitlab::Llm::AiGateway::ModelMetadata.new(feature_setting: feature_setting).to_params
            return unless model_metadata.present?

            { 'x-gitlab-self-hosted-models-metadata' => model_metadata.to_json }
          end

          private

          attr_reader :feature_setting

          def feature_flag_enabled?
            Feature.enabled?(:agent_platform_model_selection) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- This is an instance level feature flag
          end
        end
      end
    end
  end
end
