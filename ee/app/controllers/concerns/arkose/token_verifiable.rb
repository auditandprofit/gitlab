# frozen_string_literal: true

module Arkose
  module TokenVerifiable
    extend ActiveSupport::Concern
    include ::Gitlab::Utils::StrongMemoize

    private

    def verify_arkose_labs_token(user: nil)
      return true unless arkose_labs_enabled?(user: user)
      return true if arkose_labs_verify_response(user: user).present?

      if arkose_down?
        user&.assume_low_risk!(reason: 'Arkose is down')
        log_challenge_skipped
        return true
      end

      log_token_missing
      false
    end

    def arkose_labs_verify_response(user: nil)
      strong_memoize_with(:arkose_labs_verify_response, user) do
        result = Arkose::TokenVerificationService.new(session_token: token, user: user).execute
        result.success? ? result.payload[:response] : nil
      end
    end

    def arkose_interactive_challenge_solved?
      return false unless arkose_labs_verify_response

      arkose_labs_verify_response.interactive_challenge_solved?
    end

    def log_challenge_skipped
      ::Gitlab::AppLogger.info(
        message: 'Sign-up verification skipped',
        reason: 'arkose is experiencing an outage',
        username: username
      )
    end

    def log_token_missing
      ::Gitlab::AppLogger.info(
        message: 'Sign-up blocked',
        reason: 'arkose token is missing in request',
        username: username
      )
    end

    def track_arkose_challenge_result
      log_arkose_challenge_solved(interactive: arkose_interactive_challenge_solved?)
    end

    def log_arkose_challenge_solved(interactive: false)
      challenge_type = interactive ? 'interactive' : 'transparent'

      ::Gitlab::AppLogger.info(
        username: username,
        message: "Arkose challenge",
        event: "#{challenge_type} challenge solved"
      )
    end

    def token
      @token ||= params[:arkose_labs_token].to_s
    end

    def arkose_down?
      Arkose::StatusService.new.execute.error?
    end
  end
end
