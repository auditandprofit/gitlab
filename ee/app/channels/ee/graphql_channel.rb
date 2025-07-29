# frozen_string_literal: true

module EE
  module GraphqlChannel
    extend ActiveSupport::Concern

    prepended do
      def authorization_scopes
        super + [:ai_features]
      end
    end
  end
end
