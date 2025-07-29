# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      module ModelSwitching
        class AiGateway < CodeSuggestions::Prompts::Base
          include CodeSuggestions::Prompts::CodeCompletion::Anthropic::Concerns::Prompt
          include Gitlab::Loggable

          GATEWAY_PROMPT_VERSION = 3
          MODEL_PROVIDER = 'gitlab'
          GITLAB_PROVIDED_CLAUDE_SONNET_35_MODEL_NAME = 'claude_3_5_sonnet_20240620'
          GITLAB_PROVIDED_ANTHROPIC_MODELS_FOR_CODE_COMPLETION = [
            'claude_sonnet_3_7_20250219',
            GITLAB_PROVIDED_CLAUDE_SONNET_35_MODEL_NAME
          ].freeze

          def initialize(params, current_user, feature_setting, user_group_with_claude_code_completion)
            @user_group_with_claude_code_completion = user_group_with_claude_code_completion
            super(params, current_user, feature_setting)
          end

          def request_params
            model_name = determine_model_name

            {
              model_provider: self.class::MODEL_PROVIDER,
              model_name: model_name.to_s,
              prompt_version: self.class::GATEWAY_PROMPT_VERSION,
              prompt: find_prompt(model_name)
            }
          end

          private

          attr_reader :user_group_with_claude_code_completion

          def find_prompt(model_name)
            # We still need to pass the prompt due to legacy reasons, but only for Anthropic models.
            # See https://gitlab.com/gitlab-org/gitlab/-/issues/548241#note_2553250550 for details.
            return unless GITLAB_PROVIDED_ANTHROPIC_MODELS_FOR_CODE_COMPLETION.include?(model_name.to_s)

            prompt
          end

          def root_namespace_id
            params[:project]&.root_namespace&.id
          end

          def determine_model_name
            if user_group_with_claude_code_completion.present?
              namespace_feature_setting_from_user_group =
                ::Ai::ModelSelection::NamespaceFeatureSetting.find_or_initialize_by_feature(
                  user_group_with_claude_code_completion, :code_completions)

              model_to_be_used = if namespace_feature_setting_from_user_group.nil? ||
                  namespace_feature_setting_from_user_group.set_to_gitlab_default?
                                   GITLAB_PROVIDED_CLAUDE_SONNET_35_MODEL_NAME
                                 else
                                   namespace_feature_setting_from_user_group.offered_model_ref
                                 end

              if feature_setting.nil?
                Gitlab::AppJsonLogger.debug(
                  build_structured_payload(
                    root_namespace_id: root_namespace_id,
                    user_group_with_claude_code_completion_id: user_group_with_claude_code_completion.id,
                    model_to_be_used: model_to_be_used,
                    message: 'Model switching executed for code completion without a feature setting'
                  )
                )
              end

              return model_to_be_used
            end

            # Based on the caller, a `nil` feature setting will only exist
            # in cases where user_group_with_claude_code_completion is present.
            # That case is already handled above.
            # In all other cases, the feature setting will be present.
            feature_setting.offered_model_ref
          end
        end
      end
    end
  end
end
