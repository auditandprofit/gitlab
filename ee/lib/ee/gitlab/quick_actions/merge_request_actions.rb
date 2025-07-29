# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module MergeRequestActions
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override
        include ::Gitlab::QuickActions::Dsl
        include ::Gitlab::Utils::StrongMemoize

        included do
          desc { _('Change reviewers') }
          explanation { _('Change reviewers.') }
          execution_message { _('Changed reviewers.') }
          params '@user1 @user2'
          types MergeRequest
          condition do
            quick_action_target.allows_multiple_reviewers? &&
              quick_action_target.persisted? &&
              current_user.can?(:"admin_#{quick_action_target.to_ability_name}", project)
          end
          command :reassign_reviewer do |reassign_param|
            @updates[:reviewer_ids] = extract_users(reassign_param).map(&:id)
          end
        end

        override :process_reviewer_users
        def process_reviewer_users(users)
          strong_memoize_with(:process_reviewer_users, users.map(&:id)) do
            next users if users.empty?

            duo_bot = ::Users::Internal.duo_code_review_bot

            next users unless users.include?(duo_bot)
            next users if quick_action_target.ai_review_merge_request_allowed?(current_user)

            # Set flag to use in execution_message and flash message in controller
            quick_action_target.duo_code_review_attempted = true

            users - [duo_bot]
          end
        end

        override :process_reviewer_users_message
        def process_reviewer_users_message
          return unless quick_action_target.duo_code_review_attempted

          s_("DuoCodeReview|Your account doesn't have GitLab Duo access. " \
            "Please contact your system administrator for access.")
        end
      end
    end
  end
end
