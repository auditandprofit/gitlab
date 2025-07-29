# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiUsage
      class UsageEventsResolver < BaseResolver
        type ::Types::Analytics::AiUsage::AiUsageEventType.connection_type, null: true

        def ready?(**args)
          return super unless should_raise_error?

          raise Gitlab::Graphql::Errors::ArgumentError, 'Not available for this resource.'
        end

        def resolve
          ::Ai::UsageEventsFinder.new(current_user, resource: object).execute
        end

        private

        # In this first iteration this endpoint is limited
        # only to top-level groups because still there is no
        # way to filter data in a reliable way.
        # We can remove this check after namespace_path is populated into ai_code_suggestion_events table,
        # for more information check https://gitlab.com/gitlab-org/gitlab/-/issues/490601#note_2122055518.
        def should_raise_error?
          return true if Feature.disabled?(:unified_ai_events_graphql, object)
          return true if object.is_a?(Project)
          return true unless object.root?

          false
        end
      end
    end
  end
end
