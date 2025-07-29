# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeGeneration < CodeSuggestions::Tasks::Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      delegate :supports_sse_streaming?, to: :client

      override :endpoint
      def endpoint
        return "#{base_url}/v4/code/suggestions" if supports_sse_streaming?

        "#{base_url}/v3/code/completions"
      end

      private

      def model_details
        @model_details ||= CodeSuggestions::ModelDetails::Base.new(
          current_user: current_user,
          feature_setting_name: :code_generations,
          root_namespace: params[:project]&.root_ancestor
        )
      end

      def prompt
        CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages.new(params, current_user, feature_setting)
      end

      strong_memoize_attr :prompt
    end
  end
end
