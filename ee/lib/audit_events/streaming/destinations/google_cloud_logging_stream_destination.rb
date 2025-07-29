# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Destinations
      class GoogleCloudLoggingStreamDestination < BaseStreamDestination
        def stream
          gcp_logger = AuditEvents::GoogleCloud::LoggingService::Logger.new
          gcp_logger.log(@destination.config["clientEmail"], @destination.secret_token, json_payload)
        rescue StandardError => e
          Gitlab::ErrorTracking.log_exception(e)
        end

        private

        def json_payload
          { 'entries' => [log_entry] }.to_json
        end

        def log_entry
          {
            'logName' => full_log_path,
            'resource' => {
              'type' => 'global'
            },
            'severity' => 'INFO',
            'jsonPayload' => ::Gitlab::Json.parse(request_body)
          }
        end

        def full_log_path
          "projects/#{@destination.config['googleProjectIdName']}/logs/#{@destination.config['logIdName']}"
        end
      end
    end
  end
end
