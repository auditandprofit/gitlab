# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      class AiUsageEventTypeEnum < BaseEnum
        graphql_name 'AiUsageEventType'
        description 'Type of AI usage event'

        DEPRECATION_POSTFIX = "Old data only."

        def self.declare_event(event_name, description)
          description += " #{DEPRECATION_POSTFIX}" if Gitlab::Tracking::AiTracking.deprecated_event?(event_name)

          value event_name.upcase, description: description, value: event_name
        end

        declare_event('code_suggestions_requested', "Code Suggestion was requested.")
        declare_event('code_suggestion_shown_in_ide', "Code Suggestion was shown in IDE.")
        declare_event('code_suggestion_accepted_in_ide', "Code Suggestion was accepted in IDE.")
        declare_event('code_suggestion_rejected_in_ide', "Code Suggestion was rejected in IDE.")
        declare_event('code_suggestion_direct_access_token_refresh', "Code Suggestion token was refreshed.")
        declare_event('request_duo_chat_response', "Duo Chat response was requested.")
        declare_event('troubleshoot_job', "Troubleshoot job feature was used.")
      end
    end
  end
end
