# frozen_string_literal: true

module Namespaces
  module BlockSeatOverages
    class AllSeatsUsedAlertComponent < ViewComponent::Base
      def initialize(context:, content_class:, current_user:)
        @root_namespace = context&.root_ancestor
        @content_class = content_class
        @current_user = current_user
      end

      attr_reader :root_namespace, :content_class, :current_user

      def render?
        return false unless group_namespace? && owner? && block_seat_overages? && !user_dismissed_alert?

        all_seats_used?
      end

      private

      def group_namespace?
        root_namespace&.group_namespace?
      end

      def block_seat_overages?
        subscription&.has_a_paid_hosted_plan? && root_namespace.block_seat_overages?
      end

      def subscription
        root_namespace.gitlab_subscription
      end

      def owner?
        Ability.allowed?(current_user, :owner_access, root_namespace)
      end

      def all_seats_used?
        billable_members_count = root_namespace.billable_members_count_with_reactive_cache

        return false if billable_members_count.blank?

        subscription.seats <= billable_members_count
      end

      def user_dismissed_alert?
        current_user.dismissed_callout_for_group?(
          feature_name: EE::Users::GroupCalloutsHelper::ALL_SEATS_USED_ALERT,
          group: root_namespace
        )
      end
    end
  end
end
