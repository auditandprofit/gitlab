# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    class AddedService
      BATCH_SIZE = 100

      def initialize(source, invited_user_ids)
        @source = source
        @invited_user_ids = invited_user_ids.compact
      end

      def execute
        return ServiceResponse.error(message: 'Invalid params') unless source&.root_ancestor

        namespace_id = source.root_ancestor.id
        organization_id = source.root_ancestor.organization_id

        recently_added_members_user_ids.each_slice(BATCH_SIZE) do |batch|
          seat_assignments = batch.map do |user_id|
            {
              namespace_id: namespace_id,
              user_id: user_id,
              organization_id: organization_id
            }
          end

          GitlabSubscriptions::SeatAssignment.insert_all(
            seat_assignments,
            unique_by: [:namespace_id, :user_id]
          )
        end

        ServiceResponse.success(message: 'Member added activity tracked')
      end

      private

      attr_reader :source, :invited_user_ids

      def recently_added_members_user_ids
        source.members.connected_to_user.including_user_ids(invited_user_ids).pluck_user_ids
      end
    end
  end
end
