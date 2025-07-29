# frozen_string_literal: true

module CloudConnector
  class AvailableServices
    class << self
      def find_by_name(service_name)
        if service_name != :self_hosted_models && service_is_self_hosted?(service_name)
          service_name = :self_hosted_models
        end

        reader = select_reader(service_name)

        service_data_map = reader.read_available_services
        if service_data_map.empty? || !service_data_map[service_name].present?
          return CloudConnector::MissingServiceData.new
        end

        service_data_map[service_name]
      end

      def select_reader(service_name)
        if use_self_signed_token?(service_name) # gitlab.com or self-hosted AI Gateway
          self_signed_access_data_reader
        else
          self_managed_access_data_reader
        end
      end

      def self_signed_access_data_reader
        @self_signed_access_data_reader ||= SelfSigned::AccessDataReader.new
      end

      def self_managed_access_data_reader
        @self_managed_access_data_reader ||= SelfManaged::AccessDataReader.new
      end

      private

      def use_self_signed_token?(service_name)
        return true if ::Gitlab::Saas.feature_available?(:cloud_connector_static_catalog)
        return true if service_name == :self_hosted_models

        # All remaining code paths require requesting self-signed tokens.
        Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
      end

      def service_is_self_hosted?(service_name)
        return false if ::Gitlab::Saas.feature_available?(:cloud_connector_static_catalog)

        ::Ai::FeatureSetting.feature_for_unit_primitive(service_name)&.self_hosted?
      end
    end
  end
end
