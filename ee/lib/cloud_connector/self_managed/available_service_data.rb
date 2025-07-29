# frozen_string_literal: true

module CloudConnector
  module SelfManaged
    class AvailableServiceData < BaseAvailableServiceData
      extend ::Gitlab::Utils::Override

      override :access_token
      def access_token(_resource = nil, **)
        # for SelfManaged instances we are using instance token synced from CustomersDot
        ::CloudConnector::ServiceAccessToken.active.last&.token
      end
    end
  end
end
