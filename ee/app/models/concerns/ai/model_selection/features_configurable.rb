# frozen_string_literal: true

module Ai
  module ModelSelection
    module FeaturesConfigurable
      extend ActiveSupport::Concern
      include Ai::FeatureConfigurable

      MODEL_PROVIDER = "gitlab"

      FEATURES = {
        code_generations: 0,
        code_completions: 1,
        duo_chat: 2,
        duo_chat_explain_code: 3,
        duo_chat_write_tests: 4,
        duo_chat_refactor_code: 5,
        duo_chat_fix_code: 6,
        duo_chat_troubleshoot_job: 7,
        generate_commit_message: 8,
        summarize_new_merge_request: 9,
        duo_chat_explain_vulnerability: 10,
        resolve_vulnerability: 11,
        summarize_review: 12,
        duo_chat_summarize_comments: 14,
        review_merge_request: 15
      }.freeze
      # Duo CLI should be number 13
      # But it has been disabled here because its context not namespaced
      # See full feature list at ee/app/models/ai/feature_setting.rb
      # For more context see https://gitlab.com/groups/gitlab-org/-/epics/17570#note_2487671188

      FEATURES_UNDER_FLAGS = {
        summarize_review: :summarize_my_code_review,
        summarize_new_merge_request: :add_ai_summary_for_new_mr
      }.freeze
      # Keys are :feature enum values
      # Values are the names of the Feature Flags used to enable the features
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/543087 for more context

      DUO_CHAT_FEATURES = [
        :duo_chat,
        :duo_chat_explain_code,
        :duo_chat_write_tests,
        :duo_chat_refactor_code,
        :duo_chat_fix_code,
        :duo_chat_troubleshoot_job,
        :duo_chat_explain_vulnerability,
        :duo_chat_summarize_comments
      ].freeze

      DUO_CHAT_TOOLS = [
        :duo_chat_build_reader,
        :duo_chat_epic_reader,
        :duo_chat_issue_reader,
        :duo_chat_merge_request_reader,
        :duo_chat_commit_reader,
        :duo_chat_gitlab_documentation
      ].freeze
      # Duo chat tools need to be mapped to the base 'duo_chat' feature
      # to ensure proper model selection when these tools are used.
      # This prevents bugs when tool-specific features are passed to
      # Gitlab::Llm::Chain::Requests::AiGateway#namespace_feature_setting
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/551318

      def model_selection_scope
        raise NotImplementedError, '#model_selection_scope method must be implemented for Model Selection logic'
      end

      included do
        enum :feature, FEATURES, validate: true

        validates :feature, presence: true
        validate :validate_model_selection_enabled
        validate :validate_model_ref_with_definition

        delegate :title, :main_feature, to: :metadata, allow_nil: true

        attribute :model_definitions, default: {}

        after_validation :set_model_name, if: -> { offered_model_ref_changed? }

        def self.find_or_initialize_by_feature
          raise NotImplementedError,
            '.find_or_initialize_by_feature method must be implemented for Model Selection logic'
        end

        # rubocop: disable Gitlab/FeatureFlagKeyDynamic -- The whole goal of this method is to dynamically filter out disabled features
        def self.enabled_features_for(feature_flag_scope)
          disabled_features = FEATURES_UNDER_FLAGS.filter_map do |feature, flag|
            feature if ::Feature.disabled?(flag, feature_flag_scope)
          end

          FEATURES.except(*disabled_features)
        end
        # rubocop: enable Gitlab/FeatureFlagKeyDynamic

        def self.get_feature_name(feature_name)
          return "duo_chat" if DUO_CHAT_TOOLS.include?(feature_name.to_sym)

          feature_name
        end

        def self_hosted?
          false
        end

        def disabled?
          false
        end

        def vendored?
          false
        end

        def provider
          MODEL_PROVIDER
        end

        def base_url
          Gitlab::AiGateway.url
        end

        def model_metadata_params
          {
            provider: provider,
            feature_setting: feature,
            identifier: offered_model_ref
          }
        end

        def model_request_params
          model_metadata_params
        end

        private

        def validate_model_selection_enabled
          return if model_selection_enabled?

          errors.add(:base,
            "Model selection is not enabled.")
        end

        def validate_model_ref_with_definition
          return if offered_model_ref.blank?

          return unless model_definition_present?

          feature_data = model_definitions['unit_primitives']&.find { |unit| unit['feature_setting'] == feature.to_s }

          unless feature_data.present?
            errors.add(:offered_model_ref, 'Feature not found in model definitions')
            return
          end

          add_model_not_compatible_error if feature_data['selectable_models'].exclude?(offered_model_ref)
        end

        def model_selection_enabled?
          ::Feature.enabled?(:ai_model_switching, model_selection_scope)
        end

        def set_model_name
          if offered_model_ref.blank?
            self.offered_model_name = offered_model_ref
            return
          end

          return unless model_definition_present?

          model_data = model_definitions['models']&.find { |model| model['identifier'] == offered_model_ref }

          if model_data.nil?
            errors.add(:offered_model_ref, 'Model reference not found in definitions')
            return
          end

          model_name_candidate = model_data['name']

          if model_name_candidate.blank?
            errors.add(:offered_model_ref, 'No model name found in model data')
            return
          end

          self.offered_model_name = model_name_candidate
        end

        def model_definition_present?
          return true if model_definitions.present?

          errors.add(:feature, "No model definition given for validation")
          false
        end

        def add_model_not_compatible_error
          errors.add(:offered_model_ref,
            "Selected model '#{offered_model_ref}' is not compatible with the feature '#{feature}'")
        end
      end
    end
  end
end
