# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class AdvantagesListComponent < ViewComponent::Base
      private

      delegate :sprite_icon, to: :helpers

      def advantages
        [
          s_('InProductMarketing|60-day trial period'),
          s_('InProductMarketing|Invite unlimited colleagues'),
          s_('InProductMarketing|Free guest users'),
          s_('InProductMarketing|Ensure compliance'),
          s_('InProductMarketing|Built-in security')
        ]
      end
    end
  end
end
