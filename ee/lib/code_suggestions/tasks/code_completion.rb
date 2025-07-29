# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeCompletion < Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      delegate :saas_primary_model_class, to: :model_details

      override :endpoint
      def endpoint
        "#{base_url}/v2/code/#{endpoint_name}"
      end

      private

      override :endpoint_name
      def endpoint_name
        'completions'
      end

      def model_details
        @model_details ||= CodeSuggestions::ModelDetails::CodeCompletion.new(
          current_user: current_user,
          root_namespace: params[:project]&.root_namespace
        )
      end

      def prompt
        if ::Ai::AmazonQ.connected?
          amazon_q_prompt
        elsif self_hosted?
          self_hosted_prompt
        elsif use_model_switching?
          model_switching_ai_gateway_prompt
        else
          saas_prompt
        end
      end
      strong_memoize_attr :prompt

      def self_hosted_prompt
        CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage.new(
          params,
          current_user,
          feature_setting
        )
      end

      def saas_prompt
        if Feature.enabled?(:incident_fail_over_completion_provider, current_user)
          CodeSuggestions::Prompts::CodeCompletion::Anthropic::ClaudeSonnet.new(params, current_user)
        else
          saas_primary_model_class.new(params, current_user)
        end
      end

      def model_switching_ai_gateway_prompt
        CodeSuggestions::Prompts::CodeCompletion::ModelSwitching::AiGateway.new(
          params,
          current_user,
          feature_setting,
          model_details.user_group_with_claude_code_completion
        )
      end

      def amazon_q_prompt
        CodeSuggestions::Prompts::CodeCompletion::AmazonQ.new(params, current_user)
      end

      def use_model_switching?
        # We take this path under 2 conditions:
        # 1. If the namespace has pinned a
        # model for code completion.
        # If the namespace has set "GitLab Default" as the model,
        # the model will continued to be decided by the Rails monolith
        # using `saas_prompt` method.
        # 2. If the namespace has
        # `use_claude_code_completion` enabled,
        # but no feature setting can be found based on the current project's details.
        (namespace_feature_setting? && !feature_setting.set_to_gitlab_default?) ||
          (model_details.user_group_with_claude_code_completion.present? && feature_setting.nil?)
      end
    end
  end
end
