# frozen_string_literal: true

module Authz
  class CustomAbility
    include Gitlab::Utils::StrongMemoize

    def initialize(user, resource = nil)
      @user = user
      @resource = resource
    end

    def allowed?(ability_name)
      ability = Definition.new(ability_name)

      return false unless enabled_for?(ability)

      abilities_for.include?(ability.name)
    end

    class << self
      def allowed?(user, ability_name, resource = nil)
        new(user, resource).allowed?(ability_name)
      end
    end

    private

    attr_reader :user, :resource

    def enabled_for?(ability)
      return false unless ability.exists?
      return false unless user.is_a?(User)
      return false if resource.is_a?(::Group) && !ability.group_ability_enabled?
      return false if resource.is_a?(::Project) && !ability.project_ability_enabled?
      return false if resource.blank? && !ability.admin_ability_enabled?
      return false unless permission_enabled?(ability)

      custom_roles_enabled?
    end

    def custom_roles_enabled?
      return License.feature_available?(:custom_roles) if resource.blank?

      return true unless resource.respond_to?(:custom_roles_enabled?)

      resource.custom_roles_enabled?
    end

    def permission_enabled?(ability)
      return ::MemberRole.admin_permission_enabled?(ability.name) if ability.admin_ability_enabled?

      ::MemberRole.permission_enabled?(ability.name, user)
    end

    def abilities_for_projects(projects)
      ::Authz::Project.new(user, scope: projects).permitted
    end

    def abilities_for_groups(groups)
      ::Authz::Group.new(user, scope: groups).permitted
    end

    def abilities_for
      case resource
      when nil
        ::Authz::Admin.new(user).permitted
      when ::Project
        abilities_for_projects([resource]).fetch(resource.id, [])
      when ::Group
        abilities_for_groups([resource]).fetch(resource.id, [])
      when Ci::Runner
        if resource.project_type?
          abilities_for_projects(resource.projects)
        else
          abilities_for_groups(resource.groups)
        end.flat_map { |(_id, abilities)| abilities }
      else
        []
      end
    end
    strong_memoize_attr :abilities_for
  end
end
