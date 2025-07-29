# frozen_string_literal: true

module SecretsManagement
  module ErrorResponseHelper
    def inactive_response
      ServiceResponse.error(message: 'Project secrets manager is not active')
    end
  end
end
