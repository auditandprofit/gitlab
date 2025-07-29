# frozen_string_literal: true

module EE
  module Notes
    module PostProcessService
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        super

        ::Analytics::RefreshCommentsData.for_note(note)&.execute

        log_audit_event if note.author.project_bot?
        process_duo_code_review_chat
      end

      private

      def log_audit_event
        audit_context = {
          name: 'comment_by_project_bot',
          author: note.author,
          scope: note.project,
          target: note,
          message: "Added comment: #{::Gitlab::UrlBuilder.note_url(note)}",
          target_details: {
            id: note.id,
            noteable_type: note.noteable_type,
            noteable_id: note.noteable_id
          },
          stream_only: true
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def process_duo_code_review_chat
        author = note.author

        # Duo Code Review should respond to any MR note when mentioned
        return unless note.for_merge_request?

        # We don't want the bot to talk to itself
        return if note.authored_by_duo_bot?

        return unless note.noteable.ai_review_merge_request_allowed?(author)
        return unless note.duo_bot_mentioned?

        ::MergeRequests::DuoCodeReviewChatWorker.perform_async(note.id)
      end
    end
  end
end
