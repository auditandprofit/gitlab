# frozen_string_literal: true

module SeatCountAlertHelper
  def show_seat_count_alert?
    @seat_count_data.present? && @seat_count_data[:namespace].present?
  end

  def remaining_seat_count
    @seat_count_data[:remaining_seat_count]
  end

  def total_seat_count
    @seat_count_data[:total_seat_count]
  end

  def namespace
    @seat_count_data[:namespace]
  end

  def seat_count_text
    if namespace.block_seat_overages?
      return _('Once you reach the number of seats in your subscription, you can no longer ' \
        'invite or add users to the namespace.')
    end

    _('Even if you reach the number of seats in your subscription, you can continue to add users, ' \
      'and GitLab will bill you for the overage.')
  end

  def seat_count_help_page_link
    return help_page_path('user/group/manage.md', anchor: 'turn-on-restricted-access') if namespace.block_seat_overages?

    help_page_path('subscriptions/quarterly_reconciliation.md')
  end
end
