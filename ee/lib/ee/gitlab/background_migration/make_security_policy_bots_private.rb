# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module MakeSecurityPolicyBotsPrivate
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :make_security_policy_bot_users_private
          scope_to ->(relation) { relation.where(user_type: 10, private_profile: false) }
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            sub_batch.update_all(private_profile: true)
          end
        end
      end
    end
  end
end
