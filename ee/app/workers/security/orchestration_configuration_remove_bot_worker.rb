# frozen_string_literal: true

module Security
  class OrchestrationConfigurationRemoveBotWorker
    include ApplicationWorker

    feature_category :security_policy_management

    data_consistency :sticky

    idempotent!

    concurrency_limit -> { 200 }

    def perform(project_id, current_user_id)
      project = Project.find_by_id(project_id)

      return if project.nil?

      current_user = User.find_by_id(current_user_id)
      return if current_user.nil?

      security_policy_bot = project.security_policy_bot
      return if security_policy_bot.nil?

      Users::DestroyService.new(current_user).execute(security_policy_bot, hard_delete: false, skip_authorization: true)
    end
  end
end
