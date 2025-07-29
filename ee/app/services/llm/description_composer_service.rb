# frozen_string_literal: true

module Llm # rubocop:disable Gitlab/BoundedContexts -- Existing LLM module
  class DescriptionComposerService < BaseService
    def valid?
      super &&
        user.can?(:access_description_composer, resource)
    end

    private

    def ai_action
      :description_composer
    end

    def perform
      schedule_completion_worker
    end
  end
end
