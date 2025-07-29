# frozen_string_literal: true

module CloudConnector
  module Tokens
    class TokenLoader
      # for SelfManaged/Dedicated instances we are using an instance token synced from CustomersDot
      def token
        ::CloudConnector::ServiceAccessToken.active.last&.token
      end
    end
  end
end
