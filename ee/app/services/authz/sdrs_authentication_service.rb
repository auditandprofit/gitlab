# frozen_string_literal: true

module Authz
  class SdrsAuthenticationService < BaseService
    AUDIENCE = 'sdrs'
    ISSUER = 'gitlab-secret-detection'
    ALGORITHM = 'RS256'
    VALIDITY_TIME = 1.hour

    SigningKeyNotConfigured = Class.new(StandardError)

    def self.generate_token(user:, project:, finding_id:)
      claims = {
        iss: ISSUER,
        sub: "user:#{user.id}",
        aud: AUDIENCE,
        exp: VALIDITY_TIME.from_now.to_i,
        iat: Time.current.to_i,
        jti: SecureRandom.uuid,
        gitlab: {
          user_id: user.id,
          project_id: project.id,
          finding_id: finding_id,
          service: 'token-verification',
          scopes: ['token:verify']
        }
      }

      begin
        JWT.encode(claims, signing_key, ALGORITHM)
      rescue OpenSSL::PKey::RSAError => e
        Gitlab::ErrorTracking.log_and_raise_exception(e)
      end
    end

    def self.signing_key
      key_pem = ::Gitlab::CurrentSettings.sdrs_jwt_signing_key
      raise SigningKeyNotConfigured, 'SDRS JWT signing key not configured' if key_pem.blank?

      OpenSSL::PKey::RSA.new(key_pem)
    end
  end
end
