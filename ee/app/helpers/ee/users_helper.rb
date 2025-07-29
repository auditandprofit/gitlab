# frozen_string_literal: true

module EE
  module UsersHelper
    extend ::Gitlab::Utils::Override

    override :display_public_email?
    def display_public_email?(user)
      return false if user.public_email.blank?
      return true unless user.provisioned_by_group

      !::Feature.enabled?(:hide_public_email_on_profile, user.provisioned_by_group)
    end

    override :impersonation_tokens_enabled?
    def impersonation_tokens_enabled?
      super && !::Gitlab::CurrentSettings.personal_access_tokens_disabled?
    end

    override :admin_users_data_attributes
    def admin_users_data_attributes(users)
      super.merge({
        is_at_seats_limit: at_seats_limit?.to_s
      })
    end

    def user_badges_in_admin_section(user)
      super(user).tap do |badges|
        badges << { text: s_('AdminUsers|Auditor'), variant: 'neutral' } if user.auditor?
        badges << { text: user.member_role.name, variant: 'info', icon: 'admin' } if user.member_role

        if !::Gitlab.com? && user.using_license_seat?
          it_s_you_index = badges.index { |badge| badge[:text] == "It's you!" } || -1

          badges.insert(it_s_you_index, { text: s_('AdminUsers|Is using seat'), variant: 'neutral' })
        end
      end
    end

    def trials_allowed?(user)
      return false unless user
      return false unless ::Gitlab::CurrentSettings.should_check_namespace_plan?

      Rails.cache.fetch(['users', user.id, 'trials_allowed?'], expires_in: 10.minutes) do
        !user.belongs_to_paid_namespace? && user.owns_group_without_trial?
      end
    end

    def user_enterprise_group_text(user)
      enterprise_group = user.user_detail&.enterprise_group
      return unless enterprise_group

      list_item_classes = '!gl-grid md:gl-grid-cols-3 gl-gap-x-3'
      group_info = link_to enterprise_group.name, admin_group_path(enterprise_group)
      user_enterprise_group = content_tag(:li, class: list_item_classes) do
        content_tag(:span, _("Enterprise user of: "), class: "gl-text-subtle") +
          content_tag(:div, "", class: "gl-col-span-2") do
            content_tag(:strong, group_info) +
              content_tag(:span, format(' (%{gid})', gid: enterprise_group.id), class: "gl-text-subtle")
          end
      end

      user_enterprise_associated = content_tag(:li, class: list_item_classes) do
        content_tag(:span, _("Enterprise user associated at: "), class: "gl-text-subtle") +
          content_tag(:div, class: "gl-col-span-2") do
            content_tag(:strong, user.user_detail.enterprise_group_associated_at.to_fs(:medium))
          end
      end
      user_enterprise_group + user_enterprise_associated
    end

    private

    override :preload_project_associations
    def preload_project_associations(projects)
      ActiveRecord::Associations::Preloader.new(records: projects, associations: :invited_groups).call
    end

    def at_seats_limit?
      return false if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions) # only available for SM instances
      return false unless ::Gitlab::CurrentSettings.seat_control_block_overages?

      licensed_seats = License.current.seats

      return false unless licensed_seats.present? && licensed_seats.nonzero?

      ::User.billable.limit(licensed_seats).count >= licensed_seats
    end
  end
end
