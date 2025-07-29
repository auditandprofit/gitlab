# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class AccessProbe < BaseProbe
        extend ::Gitlab::Utils::Override

        validate :check_access_data
        validate :validate_stale_data
        after_validation :collect_access_details

        private

        override :success_message
        def success_message
          _("Subscription synchronized successfully.")
        end

        def access_record
          # TODO: replace to `.last_catalog` when we deprecate the `data`
          @access_record ||= CloudConnector::Access.with_data.last
        end

        def check_access_data
          errors.add(:base, missing_access_data_text) unless access_record
        end

        def validate_stale_data
          return unless access_record
          return unless access_record.updated_at < CloudConnector::Access::STALE_PERIOD.ago

          errors.add(:base, stale_access_data_text)
        end

        def collect_access_details
          return unless access_record

          details.add(:updated_at, access_record.updated_at)
          details.add(:data, access_record.data)
        end

        # Keeping this as a separate translation key since we want to eventually link this
        # to subscriptions/self_managed/index.html#manually-synchronize-subscription-data
        def synchronize_subscription_cta
          _('Synchronize your subscription.')
        end

        def missing_access_data_text
          format(_("Subscription has not yet been synchronized. %{cta}"), cta: synchronize_subscription_cta)
        end

        def stale_access_data_text
          format(_("Subscription has not been synchronized recently. %{cta}"), cta: synchronize_subscription_cta)
        end
      end
    end
  end
end
