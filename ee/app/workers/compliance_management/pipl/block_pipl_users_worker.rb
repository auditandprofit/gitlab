# frozen_string_literal: true

module ComplianceManagement
  module Pipl
    class BlockPiplUsersWorker
      include ApplicationWorker
      include ::Gitlab::Utils::StrongMemoize

      urgency :low
      idempotent!
      deduplicate :until_executing
      data_consistency :sticky
      feature_category :compliance_management
      queue_namespace :cronjob

      def perform
        Gitlab::Auth::CurrentUserMode.optionally_run_in_admin_mode(admin_bot) do
          PiplUser.pipl_blockable.each_batch do |batch|
            batch.each do |pipl_user|
              with_context(user: pipl_user.user) do
                # Ensure that admin mode doesn't break the authorization cycle
                block_user(pipl_user)
              end
            end
          end
        end
      end

      private

      def block_user(pipl_user)
        result = BlockNonCompliantUserService.new(pipl_user: pipl_user, current_user: admin_bot).execute

        return unless result.error?

        Gitlab::AppLogger
          .info(message: "Error blocking user: #{pipl_user.user.id} with message #{result.message}", jid: jid)
      end

      def admin_bot
        Users::Internal.admin_bot
      end
      strong_memoize_attr :admin_bot
    end
  end
end
