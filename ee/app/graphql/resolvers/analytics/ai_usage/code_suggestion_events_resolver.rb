# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiUsage
      class CodeSuggestionEventsResolver < BaseResolver
        type ::Types::Analytics::AiUsage::CodeSuggestionEventType.connection_type, null: true

        def ready?(**args)
          return super unless should_raise_error?

          raise Gitlab::Graphql::Errors::ArgumentError, 'Not available for this resource.'
        end

        def resolve
          finder =
            ::Ai::CodeSuggestionEventsFinder
              .new(current_user, resource: object)

          offset_pagination(finder.execute)
        end

        private

        # In this first iteration this endpoint is limited
        # only to top-level groups because still there is no
        # way to filter data in a reliable way.
        # We can remove this check after namespace_path is populated into ai_code_suggestion_events table,
        # for more information check https://gitlab.com/gitlab-org/gitlab/-/issues/490601#note_2122055518.
        # Remove with use_ai_events_namespace_path_filter feature flag.
        def should_raise_error?
          return false if Feature.enabled?(:use_ai_events_namespace_path_filter, object)
          return true if object.is_a?(Project)
          return true unless object.root?

          false
        end
      end
    end
  end
end
