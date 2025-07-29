# frozen_string_literal: true

module EE
  module Groups
    module UsageQuotasController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      include GitlabSubscriptions::SeatCountAlert

      prepended do
        include OneTrustCSP
        include GoogleAnalyticsCSP

        before_action only: [:root] do
          push_frontend_feature_flag(:data_transfer_monitoring, group)
          push_frontend_feature_flag(:enable_add_on_users_pagesize_selection, group)
          push_frontend_feature_flag(:product_analytics_usage_quota_annual_data, group)
          push_frontend_feature_flag(:product_analytics_billing, group, type: :development)
          push_frontend_feature_flag(:product_analytics_billing_override, group, type: :wip)
        end
      end

      def pending_members
        render_404 unless group.user_cap_available?
      end

      def subscription_history
        history_records = group.gitlab_subscription_histories

        respond_to do |format|
          format.csv do
            send_data(
              GitlabSubscriptions::SeatUsageHistoryExportService.new(history_records).csv_data,
              type: 'text/csv; charset=utf-8',
              filename: "seat-usage-history-#{group.path}-#{Date.today}.csv"
            )
          end
        end
      end

      private

      override :seat_count_data
      def seat_count_data
        generate_seat_count_alert_data(group)
      end
    end
  end
end
