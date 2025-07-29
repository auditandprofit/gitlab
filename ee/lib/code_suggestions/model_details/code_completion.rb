# frozen_string_literal: true

module CodeSuggestions
  module ModelDetails
    class CodeCompletion < Base
      FEATURE_SETTING_NAME = 'code_completions'

      def initialize(current_user:, root_namespace: nil)
        super(current_user: current_user, feature_setting_name: FEATURE_SETTING_NAME, root_namespace: root_namespace)
      end

      # Returns model details for using direct connection in the IDE.
      # Note: Claude Haiku cannot use direct connect so isn't used in this function

      # Also, model selection logic isn't used in this function as customers that have "pinned"
      # a model for code completion are forbidden from using direct connections.
      # Customers that use "GitLab Default" as the model for code selection continue
      # to use direct connections, but the default model in this case continues to
      # be decided by the Rails monolith basis the function below and not as defined
      # in the AI Gateway's `unit_primitives.yml` file.
      def current_model
        # if self-hosted, the model details are provided by the client
        return {} if self_hosted?

        return vertex_codestral_2501_model_details if code_completion_opt_out_fireworks?

        fireworks_codestral_2501_model_details
      end

      def saas_primary_model_class
        return if self_hosted?

        if user_group_with_claude_code_completion.present?
          return CodeSuggestions::Prompts::CodeCompletion::Anthropic::ClaudeSonnet
        end

        return CodeSuggestions::Prompts::CodeCompletion::VertexCodestral if code_completion_opt_out_fireworks?

        CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral
      end

      # We check :use_claude_code_completion by the top level group
      def user_group_with_claude_code_completion
        user_duo_groups.find do |group|
          Feature.enabled?(:use_claude_code_completion, group)
        end
      end

      def any_user_groups_with_model_selected_for_completion?
        namespace_feature_settings_with_model_selected_for_completion =
          Ai::ModelSelection::NamespaceFeatureSetting.with_non_default_code_completions(
            current_user.duo_available_namespace_ids
          )

        namespace_feature_settings_with_model_selected_for_completion.any? do |namespace_feature_setting|
          Feature.enabled?(
            :ai_model_switching,
            Group.actor_from_id(namespace_feature_setting.namespace_id)
          )
        end
      end

      private

      def fireworks_codestral_2501_model_details
        {
          model_provider: CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral::MODEL_PROVIDER,
          model_name: CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral::MODEL_NAME
        }
      end

      def vertex_codestral_2501_model_details
        {
          model_provider: CodeSuggestions::Prompts::CodeCompletion::VertexCodestral::MODEL_PROVIDER,
          model_name: CodeSuggestions::Prompts::CodeCompletion::VertexCodestral::MODEL_NAME
        }
      end

      # For :code_completion_opt_out_fireworks
      # On GitLab SaaS, Duo access is managed by top-level group,
      #   so we are checking the FF by the user's top-level group
      # On GitLab self-managed, Duo access is managed on an instance level;
      #   while we can check the FF on the instance level, we will follow
      #   FF development recommendations and check by the user actor
      def code_completion_opt_out_fireworks?
        # on saas, check the user's groups
        return any_user_groups_code_completion_opt_out_fireworks? if Gitlab.org_or_com? # rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- see comment above method definition

        # on self-managed, check the ops FF against the entire instance
        instance_code_completion_opt_out_fireworks?
      end

      def any_user_groups_code_completion_opt_out_fireworks?
        user_duo_groups.any? do |group|
          Feature.enabled?(:code_completion_opt_out_fireworks, group, type: :ops)
        end
      end

      def instance_code_completion_opt_out_fireworks?
        Feature.enabled?(:code_completion_opt_out_fireworks, :instance, type: :ops)
      end

      # fetches all the top-level groups that give the user Duo Access
      #   - the User#duo_available_namespace_ids method queries the `subscription_user_add_on_assignments`
      #     by user_id and filters to active gitlab duo pro and enterprise add-ons
      #   - the `subscription_user_add_on_assignments` has a `subscription_add_on_purchases`, which has a `namespace_id`
      #   - `subscription_add_on_purchases.namespace_id` is:
      #     - always set on SaaS (https://gitlab.com/gitlab-org/gitlab/-/merge_requests/123778)
      #     - and not set on self-managed (https://gitlab.com/gitlab-org/gitlab/-/merge_requests/128899)
      def user_duo_groups
        @user_duo_groups ||= Group.by_id(current_user.duo_available_namespace_ids)
      end
    end
  end
end
