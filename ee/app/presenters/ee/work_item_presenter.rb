# frozen_string_literal: true

module EE
  module WorkItemPresenter
    extend ActiveSupport::Concern

    def promoted_to_epic_url
      return unless work_item.promoted?
      return unless Ability.allowed?(current_user, :read_epic, work_item.promoted_to_epic)

      ::Gitlab::UrlBuilder.build(work_item.promoted_to_epic)
    end
  end
end
