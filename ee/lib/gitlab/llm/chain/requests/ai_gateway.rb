# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Requests
        class AiGateway < Base
          extend ::Gitlab::Utils::Override

          include ::Gitlab::Utils::StrongMemoize
          include ::Gitlab::Llm::Concerns::AvailableModels
          include ::Gitlab::Llm::Concerns::AllowedParams
          include ::Gitlab::Llm::Concerns::EventTracking

          attr_reader :ai_client, :tracking_context, :root_namespace

          ENDPOINT = '/v1/chat/agent'
          BASE_ENDPOINT = '/v1/chat'
          BASE_PROMPTS_CHAT_ENDPOINT = '/v1/prompts/chat'
          DEFAULT_TYPE = 'prompt'
          DEFAULT_SOURCE = 'GitLab EE'
          TEMPERATURE = 0.1
          STOP_WORDS = ["\n\nHuman", "Observation:"].freeze
          DEFAULT_MAX_TOKENS = 4096

          def initialize(user, service_name: :duo_chat, tracking_context: {}, root_namespace: nil)
            @user = user
            @tracking_context = tracking_context
            @root_namespace = root_namespace
            @ai_client = ::Gitlab::Llm::AiGateway::Client.new(user, service_name: service_name,
              tracking_context: tracking_context)
          end

          def request(prompt, unit_primitive: nil)
            options = default_options.merge(prompt.fetch(:options, {}))
            return unless model_provider_valid?(options)

            response = ai_client.stream(
              url: endpoint(unit_primitive, options[:use_ai_gateway_agent_prompt]),
              body: body(prompt, options, unit_primitive: unit_primitive)
            ) do |data|
              yield data if block_given?
            end

            log_conditional_info(user,
              message: "Made request to AI Client",
              event_name: 'response_received',
              ai_component: 'duo_chat',
              prompt: prompt[:prompt],
              response_from_llm: response,
              unit_primitive: unit_primitive)

            track_prompt_size(token_size(prompt[:prompt]), provider(options))
            track_response_size(token_size(response), provider(options))

            response
          end

          private

          attr_reader :user

          def default_options
            {
              temperature: TEMPERATURE,
              stop_sequences: STOP_WORDS,
              max_tokens_to_sample: DEFAULT_MAX_TOKENS
            }
          end

          def model(options)
            return options[:model] if options[:model].present?

            CLAUDE_3_5_SONNET
          end

          def provider(options)
            AVAILABLE_MODELS.find do |_, models|
              models.include?(model(options))
            end&.first
          end

          def model_provider_valid?(options)
            provider(options)
          end

          def endpoint(unit_primitive, use_ai_gateway_agent_prompt)
            path =
              if use_ai_gateway_agent_prompt
                "#{BASE_PROMPTS_CHAT_ENDPOINT}/#{unit_primitive}"
              elsif unit_primitive.present?
                "#{BASE_ENDPOINT}/#{unit_primitive}"
              else
                ENDPOINT
              end

            base_url = feature_setting(unit_primitive)&.base_url || ::Gitlab::AiGateway.url

            "#{base_url}#{path}"
          end

          def body(prompt, options, unit_primitive: nil)
            if options[:use_ai_gateway_agent_prompt]
              request_body_agent(inputs: options[:inputs], unit_primitive: unit_primitive,
                prompt_version: options[:prompt_version])
            else
              request_body(prompt: prompt[:prompt], options: options, unit_primitive: unit_primitive)
            end
          end

          def request_body(prompt:, options: {}, unit_primitive: nil)
            {
              prompt_components: [{
                type: DEFAULT_TYPE,
                metadata: {
                  source: DEFAULT_SOURCE,
                  version: Gitlab.version_info.to_s
                },
                payload: {
                  content: prompt
                }.merge(payload_params(options)).merge(model_params(options, unit_primitive))
              }],
              stream: true
            }
          end

          def request_body_agent(inputs:, unit_primitive: nil, prompt_version: nil)
            params = {
              stream: true,
              inputs: inputs
            }

            feature_setting = feature_setting(unit_primitive)

            model_metadata = model_metadata(feature_setting)
            params[:model_metadata] = model_metadata if model_metadata.present?

            model_family = model_metadata && model_metadata[:name]
            default_version = ::Gitlab::Llm::PromptVersions.version_for_prompt("chat/#{unit_primitive}", model_family)

            is_self_hosted = feature_setting&.self_hosted? || false
            params[:prompt_version] = if is_self_hosted || ::Ai::AmazonQ.connected?
                                        default_version
                                      else
                                        prompt_version || default_version
                                      end

            params
          end

          def model_metadata(feature_setting)
            ::Gitlab::Llm::AiGateway::ModelMetadata.new(feature_setting: feature_setting).to_params
          end

          # TODO: Remove the check for merge_request_reader
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/549647
          def namespace_feature_setting(unit_primitive)
            feature = if !unit_primitive || unit_primitive == 'merge_request_reader'
                        'duo_chat'
                      else
                        "duo_chat_#{unit_primitive}"
                      end

            ::Ai::ModelSelection::NamespaceFeatureSetting.find_or_initialize_by_feature(root_namespace, feature)
          end

          def model_params(options, unit_primitive = nil)
            unit_primitive ||= options[:unit_primitive]
            feature_setting = feature_setting(unit_primitive)

            model_info = feature_setting&.model_request_params

            return model_info if model_info

            # Default model parameters
            {
              provider: provider(options),
              model: model(options)
            }
          end

          def feature_setting(unit_primitive)
            strong_memoize_with(:feature_setting, unit_primitive) do
              namespace_feature_setting(unit_primitive) || chat_feature_setting(unit_primitive: unit_primitive)
            end
          end

          def payload_params(options)
            allowed_params = ALLOWED_PARAMS.fetch(provider(options))
            params = options.slice(*allowed_params)

            { params: params }.compact_blank
          end

          def token_size(content)
            # Anthropic's APIs don't send used tokens as part of the response, so
            # instead we estimate the number of tokens based on typical token size
            # one token is roughly 4 chars.
            content.to_s.size / 4
          end

          override :tracking_class_name
          def tracking_class_name(provider)
            TRACKING_CLASS_NAMES.fetch(provider)
          end

          def chat_feature_setting(unit_primitive: nil)
            feature_name = unit_primitive ? :"duo_chat_#{unit_primitive}" : :duo_chat
            feature_setting = ::Ai::FeatureSetting.find_by_feature(feature_name)

            # fallback to duo_chat if sub feature setting is not found
            feature_setting ||= ::Ai::FeatureSetting.find_by_feature(:duo_chat)

            feature_setting
          end

          def unavailable_resources
            %w[Pipelines Vulnerabilities]
          end
        end
      end
    end
  end
end
