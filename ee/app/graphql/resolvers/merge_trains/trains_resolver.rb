# frozen_string_literal: true

module Resolvers
  module MergeTrains
    class TrainsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type ::Types::MergeTrains::TrainType.connection_type, null: true
      authorize :read_merge_train

      alias_method :project, :object

      argument :status,
        ::Types::MergeTrains::TrainStatusEnum,
        required: false,
        description: 'Filter merge trains by a specific status.'

      argument :target_branches,
        [GraphQL::Types::String],
        required: false,
        description: 'Filter merge trains by a list of target branches.'

      def resolve(status: nil, target_branches: [])
        return unless merge_trains_available? && authorize!

        ::MergeTrains::Train.all_for(project, target_branch: target_branches, status: status)
      end

      private

      def merge_trains_available?
        project.licensed_feature_available?(:merge_trains)
      end

      def authorize!
        Ability.allowed?(current_user, :read_merge_train, project) || raise_resource_not_available_error!
      end
    end
  end
end
