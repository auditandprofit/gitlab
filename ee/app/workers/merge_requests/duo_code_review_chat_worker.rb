# frozen_string_literal: true

module MergeRequests
  class DuoCodeReviewChatWorker # rubocop:disable Scalability/IdempotentWorker -- Running worker twice will create duplicate notes
    include ApplicationWorker
    include ::Gitlab::Utils::StrongMemoize
    include Gitlab::InternalEventsTracking

    feature_category :code_review_workflow
    urgency :low
    data_consistency :sticky
    worker_has_external_dependencies!
    deduplicate :until_executed
    sidekiq_options retry: 3

    def perform(note_id)
      note = Note.find_by_id(note_id)

      return unless note
      return unless note.duo_bot_mentioned?

      progress_note = create_progress_note(note)

      track_internal_event('mention_gitlabduo_in_mr_comment', user: note.author, project: note.project)

      prompt_message = prepare_prompt_message(note)
      response = execute_chat_request(prompt_message, note)
      create_note_on(note, parse_response(note, response.response_body))
    rescue StandardError => error
      Gitlab::ErrorTracking.track_exception(error)

      create_note_on(note, error_note)
    ensure
      progress_note.destroy if progress_note
    end

    private

    def prepare_prompt_message(note)
      author = note.author
      thread = author.ai_conversation_threads.create!(conversation_type: :duo_code_review)
      prompt_message = nil
      notes = note.discussion.notes

      notes.each_with_index do |note, index|
        # We skip notes that are not mentioning the bot as we don't need it included
        # in the context we send with our chat request.
        next unless note.duo_bot_mentioned? || note.authored_by_duo_bot?

        role =
          if note.authored_by_duo_bot?
            ::Gitlab::Llm::AiMessage::ROLE_ASSISTANT
          else
            ::Gitlab::Llm::AiMessage::ROLE_USER
          end

        content = build_note_content(note, index == notes.size - 1)

        # We set the MR object as the resource so that it's accessible if Duo Chat decides
        # to utilize the merge_request_reader tool with identifier type "current".
        prompt_message = save_prompt_message(author, role, note.noteable, content, thread)
      end

      prompt_message
    end

    def build_note_content(note, last_note)
      content = note.note

      return content unless note.diff_note?

      # NOTE: We currently can't handle consequent messages from the same role so we need to
      #   append the extra instruction to the user message.
      #   We could change this once https://gitlab.com/gitlab-org/gitlab/-/issues/517435 gets fixed.
      last_note ? ::Gitlab::Llm::Utils::CodeSuggestionFormatter.append_prompt(content) : content
    end

    def parse_response(note, response_body)
      return response_body unless note.diff_note?

      ::Gitlab::Llm::Utils::CodeSuggestionFormatter.parse(response_body)[:body]
    end

    def save_prompt_message(user, role, resource, content, thread)
      prompt_message = ::Gitlab::Llm::ChatMessage
        .new(
          ai_action: 'chat',
          user: user,
          content: content,
          role: role,
          context: ::Gitlab::Llm::AiMessageContext.new(resource: resource),
          thread: thread
        )

      prompt_message.save!
      prompt_message
    end

    def execute_chat_request(prompt_message, note)
      ::Gitlab::Llm::Completions::Chat
        .new(
          prompt_message,
          nil,
          additional_context: additional_context(note),
          is_duo_code_review: true
        )
        .execute
    end

    # For non-diff notes, we want to leverage Duo Chat's merge_request_reader tool
    # to provide the MR context. In case the LLM decides not to use the "current" resource identifier,
    # we provide the MR's iid in a string format recognized by MergeRequestReader::Executor::SYSTEM_PROMPT.
    # This way it has the option to use the `iid` or `reference` identifier type instead.
    def additional_context(note)
      if note.diff_note?
        {
          id: note.latest_diff_file_path,
          category: 'file',
          content: note.raw_truncated_diff_lines
        }
      else
        {
          id: 'reference',
          category: 'merge_request',
          content: "!#{note.noteable.iid}"
        }
      end
    end

    def create_note_on(note, content)
      return if content.blank?

      merge_request = note.noteable

      ::Notes::CreateService.new(
        merge_request.project,
        review_bot,
        noteable: merge_request,
        note: content,
        in_reply_to_discussion_id: note.discussion_id,
        type: note.type
      ).execute
    end

    def error_note
      s_("DuoCodeReview|I encountered some problems while responding to your query. Please try again later.")
    end

    def create_progress_note(note)
      ::SystemNotes::MergeRequestsService.new(
        noteable: note.noteable,
        container: note.project,
        author: review_bot
      ).duo_code_review_chat_started(note.discussion)
    end

    def review_bot
      ::Users::Internal.duo_code_review_bot
    end
    strong_memoize_attr :review_bot
  end
end
