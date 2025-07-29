# frozen_string_literal: true

module EE
  module MergeRequests
    module CloseService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(merge_request, commit = nil)
        super.tap do
          if current_user.project_bot?
            log_audit_event(merge_request, 'merge_request_closed_by_project_bot',
              "Closed merge request #{merge_request.title}")
          end

          publish_event(merge_request)
        end
      end

      def expire_unapproved_key(merge_request)
        merge_request.approval_state.expire_unapproved_key!
      end

      private

      def publish_event(merge_request)
        ::Gitlab::EventStore.publish(
          ::MergeRequests::ClosedEvent.new(data: {
            merge_request_id: merge_request.id
          })
        )
      end
    end
  end
end
