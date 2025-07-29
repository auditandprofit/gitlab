# frozen_string_literal: true

module VirtualRegistries
  class BaseService < ::BaseContainerService
    alias_method :registry, :container

    NETWORK_TIMEOUT = 5

    BASE_ERRORS = {
      path_not_present: ServiceResponse.error(message: 'Path not present', reason: :path_not_present),
      file_not_found_on_upstreams: ServiceResponse.error(
        message: 'File not found on any upstream',
        reason: :file_not_found_on_upstreams
      )
    }.freeze

    def initialize(registry:, current_user: nil, params: {})
      super(container: registry, current_user: current_user, params: params)
    end
  end
end
