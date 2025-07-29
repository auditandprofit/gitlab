# frozen_string_literal: true

module Authz
  class BaseRole < ApplicationRecord
    include Authz::AdminRollable

    validate :ensure_at_least_one_permission_is_enabled

    self.abstract_class = true

    class << self
      def permission_enabled?(permission, user)
        return true unless ::Feature::Definition.get("custom_ability_#{permission}")

        ## this feature flag name 'pattern' is used for all custom roles so we can't
        ## avoid dynamically passing in the name to Feature.*abled?
        ::Feature.enabled?("custom_ability_#{permission}", user) # rubocop:disable FeatureFlagKeyDynamic -- see above
      end
    end

    def ensure_at_least_one_permission_is_enabled
      return if self.class.all_customizable_permissions.keys.any? { |attr| self[attr] }

      errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
    end

    def enabled_permissions(user)
      self.class.all_customizable_permissions.filter do |permission|
        attributes[permission.to_s] && self.class.permission_enabled?(permission, user)
      end
    end
  end
end
