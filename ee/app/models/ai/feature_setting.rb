# frozen_string_literal: true

module Ai
  class FeatureSetting < ApplicationRecord
    include ::Ai::FeatureConfigurable
    include ::Ai::ModelSelection::Concerns::GitlabDefaultModelParams

    self.table_name = "ai_feature_settings"

    STABLE_FEATURES = {
      code_generations: 0,
      code_completions: 1,
      duo_chat: 2,
      duo_chat_explain_code: 3,
      duo_chat_write_tests: 4,
      duo_chat_refactor_code: 5,
      duo_chat_fix_code: 6
    }.freeze

    FLAGGED_FEATURES = {
      duo_chat_troubleshoot_job: 7,
      generate_commit_message: 8,
      summarize_new_merge_request: 9,
      duo_chat_explain_vulnerability: 10,
      resolve_vulnerability: 11,
      summarize_review: 12,
      glab_ask_git_command: 13,
      duo_chat_summarize_comments: 14,
      duo_agent_platform: 15
    }.freeze

    FEATURES = STABLE_FEATURES.merge(FLAGGED_FEATURES)

    belongs_to :self_hosted_model, foreign_key: :ai_self_hosted_model_id, inverse_of: :feature_settings

    validates :self_hosted_model, presence: true, if: :self_hosted?
    validates :feature, presence: true, uniqueness: true
    validates :provider, presence: true

    validate :validate_model, if: :self_hosted?

    scope :find_or_initialize_by_feature, ->(feature) { find_or_initialize_by(feature: feature) }
    scope :for_self_hosted_model, ->(self_hosted_model_id) { where(ai_self_hosted_model_id: self_hosted_model_id) }

    enum :provider, {
      disabled: 0,
      vendored: 1,
      self_hosted: 2
    }, default: :vendored

    enum :feature, STABLE_FEATURES.merge(FLAGGED_FEATURES)

    delegate :title, :main_feature, :compatible_llms, :release_state, to: :metadata, allow_nil: true

    class << self
      include Gitlab::Utils::StrongMemoize

      def code_suggestions_self_hosted?
        exists?(feature: [:code_generations, :code_completions], provider: :self_hosted)
      end

      def provider_titles
        {
          disabled: s_('AdminAiPoweredFeatures|Disabled'),
          vendored: s_('AdminAiPoweredFeatures|AI vendor'),
          self_hosted: s_('AdminAiPoweredFeatures|Self-hosted model')
        }.with_indifferent_access.freeze
      end

      def allowed_features
        allowed_features = STABLE_FEATURES

        if ::Ai::TestingTermsAcceptance.has_accepted?
          # FLAGGED_FEATURES are in beta status. We must ensure the GitLab Testing Terms
          # have been accepted by the user in order for them to be used.
          # https://handbook.gitlab.com/handbook/legal/testing-agreement/
          allowed_features = allowed_features.merge(FLAGGED_FEATURES)
        end

        if ::License.current&.premium?
          allowed_features.except!(
            :duo_chat_explain_vulnerability,
            :resolve_vulnerability
          )
        end

        allowed_features.stringify_keys
      end

      def feature_for_unit_primitive(unit_primitive)
        return unless unit_primitive

        feature_name = unit_primitive_to_feature_name_map[unit_primitive.to_s]

        return unless feature_name

        find_by_feature(feature_name)
      end

      def unit_primitive_to_feature_name_map
        ::Ai::FeatureConfigurable::FEATURE_METADATA.each_with_object({}) do |(feature_name, metadata), result|
          metadata['unit_primitives'].each do |unit_primitive|
            result[unit_primitive] = feature_name
          end
        end
      end
      strong_memoize_attr(:unit_primitive_to_feature_name_map)
    end

    def provider_title
      title = self.class.provider_titles[provider]
      return title unless self_hosted?

      "#{title} (#{self_hosted_model.name})"
    end

    def base_url
      return Gitlab::AiGateway.cloud_connector_url if vendored?

      Gitlab::AiGateway.url if self_hosted?
    end

    def compatible_self_hosted_models
      if compatible_llms.present?
        ::Ai::SelfHostedModel.where(model: compatible_llms)
      else
        ::Ai::SelfHostedModel.all
      end
    end

    def validate_model
      return unless compatible_llms.present?
      return unless self_hosted_model.present?

      selected_model = self_hosted_model.model

      return if compatible_llms.include?(selected_model)

      message = format(s_('AdminAiPoweredFeatures|%{selected_model} is incompatible with the %{title} feature'),
        selected_model: selected_model.capitalize,
        title: title)
      errors.add(:base, message)
    end

    def ready_for_request?
      self_hosted? && self_hosted_model
    end

    def model_metadata_params
      return params_as_if_gitlab_default_model(feature) if vendored?
      return unless ready_for_request?

      {
        provider: self_hosted_model.provider,
        name: self_hosted_model.model,
        endpoint: self_hosted_model.endpoint,
        api_key: self_hosted_model.api_token,
        identifier: self_hosted_model.identifier
      }
    end

    def model_request_params
      return params_as_if_gitlab_default_model(feature) if vendored?
      return unless ready_for_request?

      {
        provider: :litellm,
        model: self_hosted_model.model,
        model_endpoint: self_hosted_model.endpoint,
        model_api_key: self_hosted_model.api_token,
        model_identifier: self_hosted_model.identifier
      }
    end
  end
end
