# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Destinations
      class AmazonS3StreamDestination < BaseStreamDestination
        def stream
          payload = request_body
          aws_s3_client.upload_object(filename(payload), bucket_name, payload, 'application/json')
        rescue Aws::S3::Errors::ServiceError => e
          Gitlab::ErrorTracking.log_exception(e)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(e)
        end

        private

        def aws_s3_client
          @aws_s3_client ||= Aws::S3Client.new(
            @destination.config["accessKeyXid"],
            @destination.secret_token,
            @destination.config["awsRegion"]
          )
        end

        def bucket_name
          destination.config["bucketName"]
        end

        # Returns the name of the json file to be saved in the S3 bucket
        # Eg: Group/2023/09/update_approval_rules_887_1694441509820.json
        def filename(payload)
          entity_type = if audit_event['entity_type'] == 'Gitlab::Audit::InstanceScope'
                          'instance'
                        elsif audit_event['entity_type'] == 'Namespaces::UserNamespace'
                          'user'
                        else
                          # replace all non alpha numeric characters in audit_event['entity_type'] with underscore
                          audit_event['entity_type'].downcase.gsub(/[^0-9A-Za-z]+/, '_')
                        end

          "#{entity_type}/#{current_year_and_month}/#{event_type}_" \
            "#{::Gitlab::Json.parse(payload)['id']}_#{time_in_ms}.json"
        end

        def time_in_ms
          (Time.now.to_f * 1000).to_i
        end

        # @return [String] Eg: "2023/09"
        def current_year_and_month
          Date.current.strftime("%Y/%m")
        end
      end
    end
  end
end
