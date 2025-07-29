# frozen_string_literal: true

module EE
  module GroupMember
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    prepended do
      include UsageStatistics

      validate :sso_enforcement, if: -> { group && user }
      validate :group_domain_limitations, if: :group_has_domain_limitations?
      validate :validate_no_security_policy_bot_as_group_member

      scope :by_group_ids, ->(group_ids) { where(source_id: group_ids) }

      scope :with_ldap_dn, -> do
        joins(user: :identities).where("identities.provider LIKE ?", 'ldap%')
        .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422405')
      end

      scope :with_identity_provider, ->(provider) do
        joins(user: :identities).where(identities: { provider: provider })
      end

      scope :with_saml_identity, ->(provider) do
        joins(user: :identities).where(identities: { saml_provider_id: provider })
        .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422405')
      end

      scope :reporters, -> { where(access_level: ::Gitlab::Access::REPORTER) }
      scope :guests, -> { where(access_level: ::Gitlab::Access::GUEST) }
      scope :non_owners, -> { where("members.access_level < ?", ::Gitlab::Access::OWNER) }
      scope :by_user_id, ->(user_id) { where(user_id: user_id) }

      scope :eligible_approvers_by_groups, ->(groups) do
        where(source_id: groups.pluck(:id), access_level: ::Gitlab::Access::DEVELOPER...)
          .limit(::Security::ScanResultPolicy::APPROVERS_LIMIT)
      end

      attr_accessor :ignore_user_limits
    end

    class_methods do
      def member_of_group?(group, user)
        exists?(group: group, user: user)
      end

      def filter_by_enterprise_users(value)
        subquery =
          ::UserDetail.where(
            ::UserDetail.arel_table[:enterprise_group_id].eq(arel_table[:source_id]).and(
              ::UserDetail.arel_table[:user_id].eq(arel_table[:user_id]))
          )

        if value
          where_exists(subquery)
        else
          where_not_exists(subquery)
        end.allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/419933")
      end
    end

    def provisioned_by_this_group?
      user&.user_detail&.provisioned_by_group_id == source_id
    end

    def enterprise_user_of_this_group?
      user&.user_detail&.enterprise_group_id == source_id
    end

    override :prevent_role_assignement?
    def prevent_role_assignement?(current_user, params)
      return false if current_user.can_admin_all_resources?

      assigning_access_level ||= params[:access_level] || access_level
      member_role_id = params[:member_role_id]
      current_access_level = params[:current_access_level]

      # first we need to check if there are possibly more custom abilities than current user has
      return true if custom_role_abilities_too_high?(current_user, member_role_id)

      # it is awlays allowed to downgrade member access level
      # if there are not more custom abilities than current user has
      return false if current_access_level && assigning_access_level < current_access_level

      # prevent assignement in case the role access level is higher than current user's role
      group.assigning_role_too_high?(current_user, assigning_access_level)
    end

    def custom_role_abilities_too_high?(current_user, member_role_id)
      return false unless member_role_id
      return false if ::Gitlab::Access::OWNER == group.max_member_access_for_user(current_user)

      current_member = group.highest_group_member(current_user)

      current_member_role = current_member.member_role
      current_member_role_abilities = member_role_abilities(current_member_role, current_user)

      new_member_role = MemberRole.find_by_id(member_role_id)
      new_member_role_abilities = member_role_abilities(new_member_role, current_user)

      (new_member_role_abilities - current_member_role_abilities).present?
    end

    private

    override :access_level_inclusion
    def access_level_inclusion
      levels = source.access_level_values
      return if access_level.in?(levels)

      errors.add(:access_level, "is not included in the list")

      if access_level == ::Gitlab::Access::MINIMAL_ACCESS
        errors.add(:access_level, "supported on top level groups only") if group.has_parent?
        errors.add(:access_level, "not supported by license") unless group.feature_available?(:minimal_access_role)
      end
    end

    override :post_destroy_member_hook
    def post_destroy_member_hook
      super

      execute_hooks_for(:destroy)
    end

    override :post_destroy_access_request_hook
    def post_destroy_access_request_hook
      super

      execute_hooks_for(:revoke)
    end

    override :seat_available
    def seat_available
      return if ignore_user_limits

      super
    end

    def validate_no_security_policy_bot_as_group_member
      return unless user&.security_policy_bot?

      errors.add(:member_user_type, _("Security policy bot cannot be added as a group member"))
    end

    def member_role_abilities(member_role, current_user)
      return [] unless member_role

      member_role.enabled_permissions(current_user).keys
    end
  end
end
