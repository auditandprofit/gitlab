# frozen_string_literal: true

module Users
  class ExperimentalCommunicationOptInWorker
    include ApplicationWorker

    data_consistency :delayed
    feature_category :integrations
    idempotent!

    PRODUCT_INTERACTION = 'Beta Program Opt In'

    def perform(user_id)
      user = User.find_by_id(user_id)
      return if user.nil?

      ::Gitlab::SubscriptionPortal::Client.opt_in_lead(
        user_id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        email: user.notification_email_or_default,
        company_name: user.user_detail_organization.presence,
        product_interaction: PRODUCT_INTERACTION
      )
    end
  end
end
