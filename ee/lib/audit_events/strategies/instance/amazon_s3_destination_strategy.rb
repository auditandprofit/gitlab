# frozen_string_literal: true

module AuditEvents
  module Strategies
    module Instance
      class AmazonS3DestinationStrategy < BaseAmazonS3DestinationStrategy
        def streamable?
          ::License.feature_available?(:external_audit_events) &&
            AuditEvents::Instance::AmazonS3Configuration.active.exists?
        end

        private

        def destinations
          AuditEvents::Instance::AmazonS3Configuration.active.limit(5)
        end
      end
    end
  end
end
