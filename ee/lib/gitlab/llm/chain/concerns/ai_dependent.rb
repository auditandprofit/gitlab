# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Concerns
        module AiDependent
          include ::Gitlab::Llm::Concerns::Logger

          def prompt
            provider_prompt_class.prompt(prompt_options)
          end

          def request(&block)
            prompt_str = prompt
            prompt_text = prompt_str[:prompt]

            log_conditional_info(context.current_user,
              message: "Content of the prompt from chat request",
              event_name: 'prompt_content',
              ai_component: 'duo_chat',
              prompt: prompt_text)

            if use_ai_gateway_agent_prompt?
              prompt_str[:options] ||= {}
              prompt_str[:options].merge!({
                use_ai_gateway_agent_prompt: true,
                inputs: prompt_options,
                prompt_version: prompt_version
              })
            end

            ai_request.request(prompt_str, unit_primitive: unit_primitive, &block)
          end

          def streamed_request_handler(streamed_answer)
            proc do |content|
              next unless stream_response_handler

              chunk = streamed_answer.next_chunk(content)

              if chunk
                stream_response_handler.execute(
                  response: Gitlab::Llm::Chain::StreamedResponseModifier
                              .new(streamed_content(content, chunk), chunk_id: chunk[:id]),
                  options: { chunk_id: chunk[:id] }
                )
              end
            end
          end

          private

          def ai_request
            context.ai_request
          end

          def provider_prompt_class
            ai_provider_name = ai_request.class.name.demodulize.underscore.to_sym

            self.class::PROVIDER_PROMPT_CLASSES[ai_provider_name]
          end

          def unit_primitive
            nil
          end

          def use_ai_gateway_agent_prompt?
            false
          end

          # This method is modified in SingleActionExecutor for Duo Chat
          def streamed_content(content, _chunk)
            content
          end
        end
      end
    end
  end
end
