# frozen_string_literal: true

module Emails
  module BlockSeatOverages
    def no_more_seats(recipient_id, user_id, project_or_group, requested_member_list = [])
      recipient = User.find_by_id(recipient_id)
      user = User.find_by_id(user_id)
      return if recipient.blank? || user.blank?

      @recipient_name = recipient.name
      @user_name = user.name
      @project_or_group = project_or_group
      @project_or_group_label = project_or_group.is_a?(Group) ? _('group') : _('project')
      @buy_seats_url = ::Gitlab::Routing.url_helpers.subscription_portal_add_extra_seats_url(@project_or_group.id)
      # TODO: to be provided later: see https://gitlab.com/gitlab-org/gitlab/-/issues/446061
      @subscription_info_url = ''
      @requested_member_list = requested_member_list

      email_with_layout(
        to: recipient.notification_email_or_default,
        subject: subject('Action required: Purchase more seats')
      )
    end
  end
end
