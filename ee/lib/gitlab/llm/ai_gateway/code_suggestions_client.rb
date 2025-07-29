# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class CodeSuggestionsClient
        include ::Gitlab::Utils::StrongMemoize
        include Gitlab::Llm::Concerns::Logger

        COMPLETION_CHECK_TIMEOUT = 3.seconds
        DEFAULT_TIMEOUT = 30.seconds

        AiGatewayError = Class.new(StandardError)

        def initialize(user)
          @user = user
        end

        def test_completion
          response = call_endpoint task.endpoint, task.body

          return "AI Gateway returned code #{response.code}: #{response.body}" unless response.code == 200
          return "Response doesn't contain a completion" unless choice?(response)

          nil
        rescue StandardError => err
          Gitlab::ErrorTracking.track_exception(err)
          err.message
        end

        def test_model_connection(self_hosted_model)
          return 'No self-hosted model was provided' unless self_hosted_model

          test_task = generate_test_task(self_hosted_model)

          response = call_endpoint test_task.endpoint, test_task.body

          if response.code == 421 # Misdirected Request https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/421
            # this means that the model server returned an error
            # The body contains the error code

            model_response_code = ::Gitlab::Json.parse(response.body)["detail"]
            return "The self-hosted model server returned code #{model_response_code}"
          end

          unless response.code == 200

            response_message = begin
              ::Gitlab::Json.parse(response.body).dig("detail", 0, "msg")
            rescue StandardError
              'Unknown error. Make sure your self-hosted model is running ' \
                'and that your AI Gateway URL is configured correctly.'
            end

            return "AI Gateway returned code #{response.code}: #{response_message}"
          end

          nil
        rescue StandardError => err
          Gitlab::ErrorTracking.track_exception(err)
          err.message
        end

        def call_endpoint(endpoint, body)
          Gitlab::HTTP.post(
            endpoint,
            headers: Gitlab::AiGateway.headers(user: user, service: service),
            body: body,
            timeout: COMPLETION_CHECK_TIMEOUT,
            allow_local_requests: true
          )
        end

        def direct_access_token
          log_info(message: 'Creating user access token',
            event_name: 'user_token_created',
            ai_component: 'code_suggestion'
          )

          response = Gitlab::HTTP.post(
            Gitlab::AiGateway.access_token_url,
            headers: Gitlab::AiGateway.headers(user: user, service: service),
            body: nil,
            timeout: DEFAULT_TIMEOUT,
            allow_local_requests: true,
            stream_body: false
          )

          raise AiGatewayError, 'Token creation failed' unless response.success?
          raise AiGatewayError, 'Token is missing in response' unless response['token'].present?

          success(token: response['token'], expires_at: response['expires_at'])
        rescue AiGatewayError => err
          error_context = {}.tap do |h|
            next if response.nil?

            h[:ai_gateway_response_code] = response.code
            if response.parsed_response.is_a?(String)
              h[:ai_gateway_error_detail] = response.parsed_response
            elsif response.respond_to?(:dig) && response.parsed_response&.dig("detail")
              h[:ai_gateway_error_detail] = response.parsed_response["detail"]
            end
          end
          Gitlab::ErrorTracking.track_exception(err, error_context)
          error(err.message)
        end

        private

        attr_reader :user

        def error(message)
          {
            message: message,
            status: :error
          }
        end

        def success(pass_back = {})
          pass_back[:status] = :success
          pass_back
        end

        def service
          ::CloudConnector::AvailableServices.find_by_name(:code_suggestions)
        end

        def choice?(response)
          response['choices']&.first&.dig('text').present?
        end

        def task
          inputs = {
            current_file: {
              file_name: 'test.rb',
              content_above_cursor: 'def hello_world'
            }
          }

          CodeSuggestions::Tasks::CodeCompletion.new(unsafe_passthrough_params: inputs, current_user: user)
        end
        strong_memoize_attr :task

        def generate_test_task(self_hosted_model)
          inputs = {
            inputs: {}
          }

          AiGateway::SelfHostedModels::Tasks::ModelConfigCheck.new(
            unsafe_passthrough_params: inputs,
            self_hosted_model: self_hosted_model,
            current_user: user
          )
        end
      end
    end
  end
end
