# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class DescriptionComposer < Gitlab::Llm::Completions::Base
          DEFAULT_ERROR = 'An unexpected error has occurred.'

          def execute
            response = response_for(user, project)
            response_modifier = modify_response(response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, project, response_modifier, options: response_options
            ).execute
          rescue StandardError => error
            Gitlab::ErrorTracking.track_exception(error)

            response_modifier = modify_response(
              { error: { message: DEFAULT_ERROR } }.to_json
            )

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, project, response_modifier, options: response_options
            ).execute

            response_modifier
          end

          private

          def project
            resource
          end

          def modify_response(response)
            ::Gitlab::Llm::Anthropic::ResponseModifiers::DescriptionComposer.new(response)
          end

          def response_for(user, project)
            template = ai_prompt_class.new(user, project, options)

            Gitlab::Llm::Anthropic::Client
              .new(user, unit_primitive: 'description_composer', tracking_context: tracking_context)
              .messages_complete(**template.to_prompt)
          end
        end
      end
    end
  end
end
