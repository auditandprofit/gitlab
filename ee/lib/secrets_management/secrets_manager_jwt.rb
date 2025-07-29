# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerJwt < Gitlab::Ci::JwtBase
    DEFAULT_TTL = 30.seconds

    attr_reader :current_user, :project

    def initialize(current_user: nil, project: nil)
      super()
      @current_user = current_user
      @project = project
    end

    def payload
      now = Time.now.to_i

      {
        iss: Gitlab.config.gitlab.url,
        iat: now,
        nbf: now,
        exp: now + DEFAULT_TTL.to_i,
        jti: SecureRandom.uuid,
        aud: 'openbao',
        sub: 'gitlab_secrets_manager',
        correlation_id: Labkit::Correlation::CorrelationId.current_id
      }.merge(project_claims)
    end

    def project_claims
      ::JSONWebToken::ProjectTokenClaims
        .new(project: project, user: current_user)
        .generate
    end
  end
end
