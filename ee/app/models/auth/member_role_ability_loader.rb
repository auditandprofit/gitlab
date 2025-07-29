# frozen_string_literal: true

module Auth
  class MemberRoleAbilityLoader
    def initialize(user:, resource:, ability:)
      @user = user
      @resource = resource
      @ability = ability
    end

    def has_ability?
      ::Authz::CustomAbility.allowed?(user, ability, resource)
    end

    private

    attr_reader :user, :resource, :ability
  end
end
