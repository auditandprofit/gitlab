# frozen_string_literal: true

module EE
  module Gitlab
    module FakeApplicationSettings
      def elasticsearch_indexes_project?(_project)
        false
      end

      def elasticsearch_indexes_namespace?(_namespace)
        false
      end

      def elasticsearch_url
        read_attribute(:elasticsearch_url).split(',').map do |s|
          URI.parse(s.strip)
        end
      end

      def elasticsearch_config
        client_request_timeout = if Rails.env.test?
                                   ApplicationSetting::ELASTIC_REQUEST_TIMEOUT
                                 else
                                   elasticsearch_client_request_timeout
                                 end

        {
          url: elasticsearch_url,
          max_bulk_size_bytes: elasticsearch_max_bulk_size_mb.megabytes,
          max_bulk_concurrency: elasticsearch_max_bulk_concurrency,
          client_request_timeout: (client_request_timeout if client_request_timeout > 0)
        }.compact
      end
    end
  end
end
