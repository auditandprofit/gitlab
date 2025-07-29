# frozen_string_literal: true

module EE
  module Gitlab
    module RackAttack
      module Request
        extend ::Gitlab::Utils::Override

        VIRTUAL_REGISTRIES_API_PACKAGE_TYPES = ::VirtualRegistries::PACKAGE_TYPES.map(&:to_s).join('|')
        VIRTUAL_REGISTRIES_API_PACKAGES_ENDPOINTS_REGEX =
          %r{^/api/v\d+/virtual_registries/packages/(?:#{VIRTUAL_REGISTRIES_API_PACKAGE_TYPES})/\d+/}

        override :should_be_skipped?
        def should_be_skipped?
          super || geo? || virtual_registries_api_endpoints?
        end

        def geo?
          if env['HTTP_AUTHORIZATION']
            ::Gitlab::Geo::JwtRequestDecoder.geo_auth_attempt?(env['HTTP_AUTHORIZATION'])
          else
            false
          end
        end

        def alerts_notify?
          web_request? && logical_path.include?('alerts/notify')
        end

        def virtual_registries_api_endpoints?
          matches?(VIRTUAL_REGISTRIES_API_PACKAGES_ENDPOINTS_REGEX)
        end
      end
    end
  end
end
