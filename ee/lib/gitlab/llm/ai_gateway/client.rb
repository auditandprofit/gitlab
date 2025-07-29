# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class Client
        include ::Gitlab::Llm::Concerns::ExponentialBackoff
        include ::Gitlab::Utils::StrongMemoize
        include ::Gitlab::Llm::Concerns::Logger
        include Langsmith::RunHelpers

        DEFAULT_TIMEOUT = 60.seconds

        ConnectionError = Class.new(StandardError)

        def initialize(user, service_name:, tracking_context: {})
          @user = user
          @service = ::CloudConnector::AvailableServices.find_by_name(service_name)
          @access_token = @service.access_token(user)
          @tracking_context = tracking_context
        end

        def complete_prompt(
          base_url:,
          prompt_name:,
          inputs:,
          timeout: DEFAULT_TIMEOUT,
          prompt_version: nil,
          model_metadata: nil
        )
          body = { 'inputs' => inputs, 'prompt_version' => prompt_version }

          body['model_metadata'] = model_metadata if model_metadata.present?

          endpoint_version = Feature.enabled?(:ai_prompts_v2, user) ? 'v2' : 'v1'

          complete(
            url: "#{base_url}/#{endpoint_version}/prompts/#{prompt_name}",
            body: body,
            timeout: timeout
          )
        end

        def complete(url:, body:, timeout: DEFAULT_TIMEOUT)
          return unless enabled?

          response = retry_with_exponential_backoff do
            resp = perform_completion_request(url: url, body: body, timeout: timeout, stream: false)

            # Log the response here because 5xx errors get swallowed by
            # Gitlab::CircuitBreaker#run_with_circuit.
            log_server_error(resp) unless resp.success?
            resp
          end

          log_response_received(response.body) if response&.success?

          response
        end

        def stream(url:, body:, timeout: DEFAULT_TIMEOUT)
          return unless enabled?

          response_body = ""

          response = perform_completion_request(
            url: url, body: body, timeout: timeout, stream: true
          ) do |chunk|
            response_body += chunk

            yield chunk if block_given?
          end

          if response.success?
            log_response_received(response_body)

            response_body
          else
            parsed_response = ::Gitlab::Json.parse(response_body)

            log_error(message: "Received error from AI gateway",
              event_name: 'error_response_received',
              ai_component: 'abstraction_layer',
              response_from_llm: parsed_response.dig('detail', 0, 'msg'))

            raise Gitlab::AiGateway::ForbiddenError if response.forbidden?

            raise ConnectionError, 'AI gateway not reachable'
          end
        end
        traceable :stream, name: 'Request to AI Gateway', run_type: 'llm'

        private

        attr_reader :user, :service, :access_token, :tracking_context

        def perform_completion_request(url:, body:, timeout:, stream:)
          log_conditional_info(user,
            message: "Performing request to AI Gateway",
            url: url,
            event_name: 'performing_request',
            ai_component: 'abstraction_layer',
            body: body,
            timeout: timeout,
            stream: stream)

          Gitlab::HTTP.post(
            url,
            headers: Gitlab::AiGateway.headers(user: user, service: service),
            body: body.to_json,
            timeout: timeout,
            allow_local_requests: true,
            stream_body: stream
          ) do |fragment|
            yield fragment if block_given?
          end
        end

        def enabled?
          access_token.present?
        end

        def log_server_error(response)
          body = response.parsed_response['detail'] if response.parsed_response.is_a?(Hash)

          log_error(message: 'Error response from AI Gateway',
            event_name: 'error_response_received',
            ai_component: 'abstraction_layer',
            status: response.code,
            body: body)
        end

        def log_response_received(response_body)
          log_conditional_info(user,
            message: 'Received response from AI Gateway',
            event_name: 'response_received',
            ai_component: 'abstraction_layer',
            response_from_llm: response_body)
        end
      end
    end
  end
end
