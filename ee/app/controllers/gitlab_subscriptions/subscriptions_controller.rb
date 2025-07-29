# frozen_string_literal: true

module GitlabSubscriptions
  class SubscriptionsController < ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include ActionView::Helpers::SanitizeHelper

    # Skip user authentication if the user is currently verifying their identity
    # by providing a payment method as part of a three-stage (payment method,
    # phone number, and email verification) identity verification process.
    # Authentication is skipped since active_for_authentication? is false at
    # this point and becomes true only after the user completes the verification
    # process.
    before_action :authenticate_user!, except: :new, unless: :identity_verification_request?

    feature_category :subscription_management
    urgency :low

    def new
      return ensure_registered! unless current_user.present?

      namespace = GitlabSubscriptions.find_eligible_namespace(user: current_user, namespace_id: params[:namespace_id])

      redirect_to purchase_url(plan_id: sanitize(params[:plan_id]), namespace: namespace)
    end

    def buy_minutes
      add_on_purchase_flow(plan_tag: 'CI_1000_MINUTES_PLAN', transaction_param: 'ci_minutes')
    end

    def buy_storage
      add_on_purchase_flow(plan_tag: 'STORAGE_PLAN', transaction_param: 'storage')
    end

    def payment_form
      response = client.payment_form_params(params[:id], current_user&.id)
      render json: response[:data]
    end

    def payment_method
      response = client.payment_method(params[:id])
      render json: response[:data]
    end

    def validate_payment_method
      user_id = identity_verification_request? ? identity_verification_user.id : current_user.id

      response = client.validate_payment_method(params[:id], { gitlab_user_id: user_id })

      render json: response
    end

    private

    def purchase_url(plan_id:, namespace:, **params)
      GitlabSubscriptions::PurchaseUrlBuilder.new(plan_id: plan_id, namespace: namespace).build(**params)
    end

    def add_on_purchase_flow(plan_tag:, transaction_param:)
      plan_id = plan_id_for_tag(tag: plan_tag)

      return render_404 unless plan_id.present?

      namespace = GitlabSubscriptions.find_eligible_namespace(
        user: current_user,
        namespace_id: params[:selected_group],
        plan_id: plan_id
      )

      return render_404 unless namespace.present?

      redirect_to purchase_url(plan_id: plan_id, namespace: namespace, transaction: transaction_param)
    end

    def client
      Gitlab::SubscriptionPortal::Client
    end

    def plan_id_for_tag(tag:)
      plan_response = client.get_plans(tags: [tag])

      plan_response[:success] ? plan_response[:data].first['id'] : nil
    end

    def ensure_registered!
      store_location_for(:user, request.fullpath)

      redirect_to new_user_registration_path
    end

    def identity_verification_request?
      # true only for actions used to verify a user's credit card
      return false unless %w[payment_form validate_payment_method].include?(action_name)

      identity_verification_user.present? && !identity_verification_user.credit_card_verified?
    end

    def identity_verification_user
      strong_memoize(:identity_verification_user) do
        User.find_by_id(session[:verification_user_id])
      end
    end
  end
end

GitlabSubscriptions::SubscriptionsController.prepend_mod
