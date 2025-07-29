# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module SelfHostedModels
        class TestedModelDetails
          MockFeatureSetting = Struct.new(:self_hosted_model, :feature, :provider)

          def initialize(current_user:, self_hosted_model:)
            @current_user = current_user
            @self_hosted_model = self_hosted_model
          end

          def feature_setting
            @feature_setting = MockFeatureSetting.new(self_hosted_model, "code_completions", "self_hosted")
          end

          def base_url
            Gitlab::AiGateway.url
          end

          def feature_disabled?
            false
          end

          def self_hosted?
            true
          end

          attr_reader :current_user, :self_hosted_model
        end
      end
    end
  end
end
