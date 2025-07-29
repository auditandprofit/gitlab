# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    class DestroyedWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :delayed
      feature_category :seat_cost_management
      urgency :low
      idempotent!
      deduplicate :until_executed

      def handle_event(event)
        user = ::User.find_by_id(event.data[:user_id])
        namespace = ::Namespace.find_by_id(event.data[:root_namespace_id])

        return unless user && namespace&.group_namespace?

        return if ::Member.in_hierarchy(namespace).with_user(user).exists?

        GitlabSubscriptions::SeatAssignment.find_by_namespace_and_user(namespace, user)&.destroy
      end
    end
  end
end
