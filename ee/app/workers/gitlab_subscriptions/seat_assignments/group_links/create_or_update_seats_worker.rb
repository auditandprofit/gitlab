# frozen_string_literal: true

module GitlabSubscriptions
  module SeatAssignments
    module GroupLinks
      class CreateOrUpdateSeatsWorker
        include ApplicationWorker

        feature_category :seat_cost_management
        data_consistency :delayed

        idempotent!

        def perform(link_id)
          link = GroupGroupLink.find_by_id(link_id)

          return unless link

          invited_group = link.shared_with_group
          root_namespace = link.shared_group.root_ancestor

          return if root_namespace.id == invited_group.root_ancestor.id

          invited_group.group_members.preload_users.each_batch do |batch|
            seats_by_user_id = ::GitlabSubscriptions::SeatAssignment
              .by_namespace(root_namespace)
              .by_user(batch.pluck_user_ids)
              .index_by(&:user_id)

            batch.each do |member|
              user = member.user
              seat = seats_by_user_id[user.id]
              seat_type = seat_type_for(root_namespace, member, link)

              if seat
                seat.update!(seat_type: seat_type) unless seat.base?
              else
                ::GitlabSubscriptions::SeatAssignment.create!(
                  namespace: root_namespace,
                  user: user,
                  organization_id: root_namespace.organization_id,
                  seat_type: seat_type
                )
              end
            end
          end
        end

        def seat_type_for(root_namespace, member, link)
          access_level = [member.access_level, link.group_access].min

          if access_level == ::Gitlab::Access::GUEST && root_namespace.exclude_guests?
            :free
          elsif access_level == ::Gitlab::Access::PLANNER
            :plan
          else
            :base
          end
        end
      end
    end
  end
end
