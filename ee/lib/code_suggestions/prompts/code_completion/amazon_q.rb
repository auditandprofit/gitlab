# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class AmazonQ < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2
        MODEL_PROVIDER = 'amazon_q'

        def request_params
          {
            prompt_version: GATEWAY_PROMPT_VERSION,
            model_provider: self.class::MODEL_PROVIDER,
            model_name: self.class::MODEL_PROVIDER,
            role_arn: ::Ai::Setting.instance.amazon_q_role_arn
          }
        end
      end
    end
  end
end
