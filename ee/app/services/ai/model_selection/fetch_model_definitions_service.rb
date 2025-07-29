# frozen_string_literal: true

module Ai
  module ModelSelection
    class FetchModelDefinitionsService
      include ::Gitlab::Llm::Concerns::Logger

      DEFAULT_TIMEOUT = 5.seconds
      RESPONSE_CACHE_EXPIRATION = 1.hour
      RESPONSE_CACHE_NAME = 'ai_offered_model_definitions'

      def initialize(user, model_selection_scope:)
        @user = user
        @model_selection_scope = model_selection_scope
      end

      def execute(force_api_call: false)
        return unless model_selection_enabled?

        return cached_response if Rails.cache.exist?(RESPONSE_CACHE_NAME) && !force_api_call

        fetch_model_definitions
      end

      private

      attr_reader :user, :model_selection_scope

      def model_selection_enabled?
        return false unless ::Feature.enabled?(:ai_model_switching, model_selection_scope)

        return false unless ::Gitlab::CurrentSettings.current_application_settings.duo_features_enabled

        true
      end

      def fetch_model_definitions
        response = call_endpoint

        if response.success?
          cache_response(response.parsed_response)
          ServiceResponse.success(payload: response.parsed_response)
        else
          parsed_response = response.parsed_response
          error_message = "Received error #{response.code} from AI gateway when fetching model definitions"

          log_error(message: error_message,
            event_name: 'error_response_received',
            ai_component: 'abstraction_layer',
            response_from_llm: parsed_response)

          ServiceResponse.error(message: error_message)
        end
      end

      def call_endpoint
        Gitlab::HTTP.get(
          endpoint,
          headers: Gitlab::AiGateway.headers(user: user, service: service),
          timeout: DEFAULT_TIMEOUT,
          allow_local_requests: true
        )
      end

      def cache_response(response_body)
        Rails.cache.fetch(RESPONSE_CACHE_NAME, expires_in: 1.hour) do
          response_body
        end
      end

      def cached_response
        cached_model_definitions = Rails.cache.fetch(RESPONSE_CACHE_NAME)
        ServiceResponse.success(payload: cached_model_definitions)
      end

      def endpoint
        base_url = Gitlab::AiGateway.url
        endpoint_route = 'models%2Fdefinitions'

        "#{base_url}/v1/#{endpoint_route}"
      end

      def service
        ::CloudConnector::AvailableServices.find_by_name(:code_suggestions)
      end
    end
  end
end
