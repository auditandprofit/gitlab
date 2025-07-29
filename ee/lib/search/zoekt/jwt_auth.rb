# frozen_string_literal: true

module Search
  module Zoekt
    module JwtAuth
      ISSUER = 'gitlab'
      AUDIENCE = 'gitlab-zoekt'
      TOKEN_EXPIRE_TIME = 5.minutes

      class << self
        def secret_token
          Gitlab::Shell.secret_token
        end

        def jwt_token
          current_time = Time.current.to_i
          payload = {
            iat: current_time,
            exp: current_time + TOKEN_EXPIRE_TIME.to_i,
            iss: ISSUER,
            aud: AUDIENCE
          }

          JWT.encode(payload, secret_token, 'HS256')
        end

        def authorization_header
          "Bearer #{jwt_token}"
        end
      end
    end
  end
end
