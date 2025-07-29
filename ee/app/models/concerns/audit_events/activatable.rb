# frozen_string_literal: true

module AuditEvents
  module Activatable
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(active: true) }
    end

    def active?
      active
    end

    def activate!
      update!(active: true)
    end

    def deactivate!
      update!(active: false)
    end
  end
end
