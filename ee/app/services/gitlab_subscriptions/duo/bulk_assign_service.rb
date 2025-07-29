# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    class BulkAssignService < BaseService
      include ::GitlabSubscriptions::SubscriptionHelper
      include Gitlab::Utils::StrongMemoize

      ERROR_NOT_ENOUGH_SEATS = 'NOT_ENOUGH_SEATS'
      ERROR_INVALID_USER_ID_PRESENT = 'INVALID_USER_ID_PRESENT'
      ERROR_INCOMPATIBLE_ADD_ON = 'INCOMPATIBLE_ADD_ON'

      NotEnoughSeatsError = Class.new(StandardError)

      def initialize(add_on_purchase:, user_ids:)
        @add_on_purchase = add_on_purchase
        @user_ids = user_ids.to_set
        @duo_type = add_on_purchase.add_on.name.to_sym
      end

      def execute
        return invalid_add_on unless GitlabSubscriptions::AddOn::DUO_ADD_ONS.include?(duo_type)

        ineligible_user_ids = user_ids - eligible_user_ids
        return invalid_user_id_present if ineligible_user_ids.any?

        ensure_seat_availability

        upsert_data = eligible_user_ids.map { |user_id| { user_id: user_id } }

        add_on_purchase.with_lock do
          ensure_seat_availability

          add_on_purchase.assigned_users.upsert_all(
            upsert_data,
            unique_by: %i[add_on_purchase_id user_id]
          )
        end

        if gitlab_com_subscription?
          ::Onboarding::AddOnSeatAssignmentIterableTriggerWorker
            .perform_async(namespace.id, eligible_user_ids.to_a, iterable_worker_params)
        else
          ::GitlabSubscriptions::AddOnPurchases::EmailOnDuoBulkUserAssignmentsWorker
            .perform_async(eligible_user_ids.to_a, email_variant)
        end

        Gitlab::AppLogger.info(log_events(type: 'success',
          payload: { users: eligible_user_ids }))
        ServiceResponse.success(payload: { users: User.id_in(eligible_user_ids) })

      rescue NotEnoughSeatsError
        not_enough_seats
      end

      private

      attr_reader :add_on_purchase, :user_ids, :duo_type

      def iterable_worker_params
        {
          'product_interaction' =>
            ::GitlabSubscriptions::AddOns::VARIANTS[duo_type][:product_interaction]
        }
      end

      def email_variant
        ::GitlabSubscriptions::AddOns::VARIANTS[duo_type][:email]
      end

      def invalid_user_id_present
        Gitlab::AppLogger.error(log_events(type: 'error',
          payload: { errors: ERROR_INVALID_USER_ID_PRESENT, user_ids: user_ids }))
        ServiceResponse.error(message: ERROR_INVALID_USER_ID_PRESENT)
      end

      def not_enough_seats
        Gitlab::AppLogger.error(log_events(type: 'error', payload: { errors: ERROR_NOT_ENOUGH_SEATS }))
        ServiceResponse.error(message: ERROR_NOT_ENOUGH_SEATS)
      end

      def ensure_seat_availability
        raise NotEnoughSeatsError unless seats_available?
      end

      def invalid_add_on
        Gitlab::AppLogger.error(log_events(type: 'error', payload: { errors: ERROR_INCOMPATIBLE_ADD_ON }))
        ServiceResponse.error(message: ERROR_INCOMPATIBLE_ADD_ON)
      end

      def seats_available?
        assigned_user_ids = assigned_users.select(:user_id).map(&:user_id)
        available_seats = add_on_purchase.quantity - assigned_user_ids.count

        available_seats >= eligible_users_count_excluding_assigned_users(assigned_user_ids)
      end

      def eligible_users_count_excluding_assigned_users(assigned_user_ids)
        eligible_user_ids.count { |user_id| assigned_user_ids.exclude?(user_id) }
      end

      def assigned_users
        add_on_purchase.assigned_users
      end

      def eligible_user_ids
        gitlab_com_subscription? ? saas_eligible_user_ids : sm_eligible_user_ids
      end
      strong_memoize_attr :eligible_user_ids

      def saas_eligible_user_ids
        namespace.gitlab_duo_eligible_user_ids & user_ids
      end

      # rubocop: disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- Safe because query filters based on passed user_ids
      def sm_eligible_user_ids
        GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(add_on_type: duo_type).execute
          .id_in(user_ids)
          .pluck(:id)
      end
      # rubocop: enable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit

      def namespace
        @namespace ||= add_on_purchase.namespace
      end

      def log_events(type:, payload:)
        {
          add_on_purchase_id: add_on_purchase.id,
          message: 'Duo Bulk User Assignment',
          response_type: type,
          payload: payload
        }
      end
    end
  end
end
