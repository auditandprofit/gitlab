# frozen_string_literal: true

module Arkose
  class TokenVerificationService
    attr_reader :session_token, :user, :response

    ARKOSE_LABS_DEFAULT_NAMESPACE = 'client'
    ARKOSE_LABS_DEFAULT_SUBDOMAIN = 'verify-api'

    def initialize(session_token:, user: nil)
      @session_token = session_token
      @user = user
    end

    def execute
      parsed_response = Gitlab::HTTP.perform_request(
        Net::HTTP::Post,
        arkose_verify_url,
        headers: { 'Content-Type': 'application/json' },
        body: body
      ).parsed_response

      @response = ::Arkose::VerifyResponse.new(parsed_response)

      logger.log_successful_token_verification

      return ServiceResponse.error(message: response.error) if response.invalid_token?

      RecordUserDataService.new(response: response, user: user).execute if user

      return success if response.allowlisted? || response.challenge_solved?

      logger.log_unsolved_challenge
      ServiceResponse.error(message: 'Captcha was not solved')

    rescue StandardError => error
      Gitlab::ErrorTracking.track_exception(error)

      logger.log_failed_token_verification

      # Allow user to proceed when we can't verify the token for some
      # unexpected reason (e.g. ArkoseLabs is down)
      user&.assume_low_risk!(reason: 'Unrecoverable Arkose error')
      success
    end

    private

    def body
      data = {
        private_key: AntiAbuse::IdentityVerification::Settings.arkose_private_api_key,
        session_token: session_token
      }
      data[:log_data] = user.id.to_s if user

      Gitlab::Json.generate(data)
    end

    def logger
      @logger ||= ::Arkose::Logger.new(
        session_token: session_token,
        user: user,
        verify_response: response
      )
    end

    def arkose_verify_url
      arkose_labs_namespace = ::Gitlab::CurrentSettings.arkose_labs_namespace
      subdomain = if arkose_labs_namespace == ARKOSE_LABS_DEFAULT_NAMESPACE
                    ARKOSE_LABS_DEFAULT_SUBDOMAIN
                  else
                    "#{arkose_labs_namespace}-verify"
                  end

      "https://#{subdomain}.arkoselabs.com/api/v4/verify/"
    end

    def success
      verify_response = response || ::Arkose::VerifyResponse.new({})

      ServiceResponse.success(payload: { response: verify_response })
    end
  end
end
