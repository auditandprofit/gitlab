# frozen_string_literal: true

module EE
  module Users
    module Internal
      extend ActiveSupport::Concern

      class_methods do
        extend Forwardable

        # Delegate to an instance method of the class
        def_delegators :new, :visual_review_bot, :suggested_reviewers_bot
      end

      # rubocop:disable CodeReuse/ActiveRecord -- Need to instantiate a record here
      def visual_review_bot
        email_pattern = "visual_review%s@#{Settings.gitlab.host}"

        unique_internal(::User.where(user_type: :visual_review_bot), 'visual-review-bot', email_pattern) do |u|
          u.bio = 'The Gitlab Visual Review feedback bot'
          u.name = 'Gitlab Visual Review Bot'
          u.confirmed_at = Time.zone.now
          u.private_profile = true
        end
      end

      def suggested_reviewers_bot
        email_pattern = "suggested-reviewers-bot%s@#{Settings.gitlab.host}"

        unique_internal(
          ::User.where(user_type: :suggested_reviewers_bot), 'suggested-reviewers-bot', email_pattern) do |u|
          u.bio = 'The GitLab suggested reviewers bot used for suggested reviewers'
          u.name = 'GitLab Suggested Reviewers Bot'
          u.confirmed_at = Time.zone.now
          u.private_profile = true
        end
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end
