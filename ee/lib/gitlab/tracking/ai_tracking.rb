# frozen_string_literal: true

module Gitlab
  module Tracking
    module AiTracking
      extend AiUsageEventsRegistryDsl

      register do
        deprecated_events(code_suggestions_requested: 1) # old data

        events(
          code_suggestion_shown_in_ide: 2,
          code_suggestion_accepted_in_ide: 3,
          code_suggestion_rejected_in_ide: 4
        ) do |context|
          context.slice(*%w[unique_tracking_id suggestion_size language branch_name])
        end

        deprecated_events(code_suggestion_direct_access_token_refresh: 5) # old data

        events(request_duo_chat_response: 6)

        events(troubleshoot_job: 7) do |context|
          {
            job_id: context['job'].id,
            project_id: context['job'].project_id,
            pipeline_id: context['job'].pipeline&.id,
            merge_request_id: context['job'].pipeline&.merge_request_id
          }
        end
      end

      class << self
        def track_event(event_name, **context_hash)
          tracked = OldApproach.track_event(event_name, **context_hash)
          tracked = UnifiedApproach.track_event(event_name, **context_hash) || tracked

          track_user_activity(context_hash[:user]) if tracked
        end

        def track_user_activity(user)
          ::Ai::UserMetrics.refresh_last_activity_on(user)
        end
      end
    end
  end
end
