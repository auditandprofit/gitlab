# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      class CodeSuggestionEventEnum < BaseEnum
        graphql_name 'AiUsageCodeSuggestionEvent'
        description 'Type of code suggestion event'

        value 'CODE_SUGGESTION_SHOWN_IN_IDE', description: 'Code suggestion shown.',
          value: 'code_suggestion_shown_in_ide'
        value 'CODE_SUGGESTION_ACCEPTED_IN_IDE', description: 'Code suggestion accepted.',
          value: 'code_suggestion_accepted_in_ide'
        value 'CODE_SUGGESTION_REJECTED_IN_IDE', description: 'Code suggestion rejected.',
          value: 'code_suggestion_rejected_in_ide'
      end
    end
  end
end
