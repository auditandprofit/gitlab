# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module SelfHostedModels
        module Tasks
          class ModelConfigCheck < ::CodeSuggestions::Tasks::Base
            def initialize(unsafe_passthrough_params:, self_hosted_model:, current_user:)
              super(unsafe_passthrough_params: unsafe_passthrough_params, current_user: current_user)

              @self_hosted_model = self_hosted_model
            end

            def endpoint_name
              'model_configuration%2Fcheck'
            end

            def endpoint
              @endpoint ||= "#{base_url}/v1/prompts/#{endpoint_name}"
            end

            def body
              body_params = unsafe_passthrough_params.merge(
                {
                  stream: false,
                  inputs: {},
                  model_metadata: model_metadata_params
                }
              )

              trim_content_params(body_params)

              body_params.to_json
            end

            private

            attr_reader :self_hosted_model

            def model_details
              @model_details ||= TestedModelDetails.new(
                current_user: current_user,
                self_hosted_model: self_hosted_model
              )
            end

            def model_metadata_params
              {
                name: self_hosted_model.model,
                endpoint: self_hosted_model.endpoint,
                api_key: self_hosted_model.api_token,
                provider: "openai",
                identifier: self_hosted_model.identifier
              }
            end
          end
        end
      end
    end
  end
end
