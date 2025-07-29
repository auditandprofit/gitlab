# frozen_string_literal: true

module Users
  class JoinEarlyAccessProgramService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def execute
      user_preference = user.user_preference
      already_participating = user_preference.early_access_program_participant?
      return if already_participating

      user_preference.update!(early_access_program_participant: true)
      ::Users::ExperimentalCommunicationOptInWorker.perform_async(user.id)
    end
  end
end
