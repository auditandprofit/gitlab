# frozen_string_literal: true

module Resolvers
  module WorkItems
    class StatusesResolver < Resolvers::WorkItems::BaseResolver
      type Types::WorkItems::StatusType.connection_type, null: true
      authorize :read_work_item_status

      alias_method :namespace, :object

      def resolve
        return unless work_item_status_feature_available?

        namespace.statuses
      end

      private

      def root_ancestor
        namespace.root_ancestor
      end
    end
  end
end
