# frozen_string_literal: true

module Notifications
  class TargetedMessage < ApplicationRecord
    validates :target_type, presence: true
    validates :targeted_message_namespaces, presence: true

    has_many :targeted_message_namespaces
    has_many :namespaces, through: :targeted_message_namespaces

    # these should map to wording/placement in the pajamas design doc: https://design.gitlab.com/
    enum :target_type, {
      banner_page_level: 0
    }
  end
end
