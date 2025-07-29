# frozen_string_literal: true

module Ai
  class SelfHostedModel < ApplicationRecord
    include Gitlab::EncryptedAttribute

    self.table_name = "ai_self_hosted_models"

    RELEASE_STATE_GA = 'GA'
    RELEASE_STATE_BETA = 'BETA'
    RELEASE_STATE_EXPERIMENTAL = 'EXPERIMENTAL'

    MODELS_RELEASE_STATE = {
      mistral: RELEASE_STATE_GA,
      llama3: RELEASE_STATE_BETA,
      codegemma: RELEASE_STATE_BETA,
      codestral: RELEASE_STATE_GA,
      codellama: RELEASE_STATE_BETA,
      deepseekcoder: RELEASE_STATE_BETA,
      claude_3: RELEASE_STATE_GA,
      gpt: RELEASE_STATE_GA,
      mixtral: RELEASE_STATE_GA
    }.freeze

    validates :model, presence: true
    validates :endpoint, presence: true, addressable_url: true
    validates :name, presence: true, uniqueness: true
    validates :identifier, length: { maximum: 255 }, allow_nil: true

    scope :ga_models, -> { where(model: MODELS_RELEASE_STATE.select { |_, state| state == RELEASE_STATE_GA }.keys) }

    has_many :feature_settings, foreign_key: :ai_self_hosted_model_id, inverse_of: :self_hosted_model

    attr_encrypted :api_token,
      mode: :per_attribute_iv,
      key: :db_key_base_32,
      algorithm: 'aes-256-gcm',
      encode: true

    enum :model, {
      mistral: 0,
      llama3: 1,
      codegemma: 2,
      codestral: 3,
      codellama: 4,
      deepseekcoder: 5,
      claude_3: 6,
      gpt: 7,
      mixtral: 8
    }

    # For now, only OpenAI API format is supported, this method will be potentially
    # converted into a configurable database column
    def provider
      :openai
    end

    def identifier
      self[:identifier] || ''
    end

    def release_state
      MODELS_RELEASE_STATE[self[:model]&.to_sym] || RELEASE_STATE_EXPERIMENTAL
    end

    def ga?
      release_state == RELEASE_STATE_GA
    end
  end
end
