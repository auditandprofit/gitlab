# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Templates
        class DescriptionComposer
          include Gitlab::Llm::Chain::Concerns::AnthropicPrompt
          include Gitlab::Utils::StrongMemoize

          USER_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_user(
            <<~PROMPT.chomp
            You are a merge request description composer. Your task is to update a specific part of a merge request description based on a user's prompt. Here's the information you'll be working with:

            <merge_request_title>
            %<title>s
            </merge_request_title>

            <merge_request_description>
            %<description>s
            </merge_request_description>

            <diffs>
            %<diff>s
            </diffs>

            <previous_response>
            %<previous_response>s
            </previous_response>

            Your goal is to update only the part of the description that is enclosed in <selected-text> tags. The user has provided a prompt to guide this update:

            <user_prompt>
            %<user_prompt>s
            </user_prompt>

            Follow these steps to complete the task:

            1. Carefully read the entire merge request description to understand the context.
            2. Locate the <selected-text> section within the description.
            3. Analyze the text surrounding the <selected-text> section to better understand which part of the description is being updated and how it relates to the rest of the content.
            4. Read the user's prompt and the diffs to gather additional context and requirements for the update.
            5. Update the content within the <selected-text> tags based on the user's prompt and the overall context of the merge request. Ensure that the updated text:
              - Addresses the user's prompt
              - Maintains consistency with the surrounding text
              - Reflects any relevant information from the diffs
              - Keeps the same tone and style as the original description
            6. Do not modify any part of the description outside of the <selected-text> tags.
            7. Return only the updated content that should replace the original <selected-text> section. Do not include the <selected-text> tags in your response.
            8. If a previous response exists, use it as the base for any updates.

            Your response should contain only the updated text, without any additional explanation or commentary. Ensure that the updated text flows seamlessly with the surrounding content in the original description.
            PROMPT
          )

          def initialize(user, project, params = {})
            @user = user
            @project = project
            @params = params
          end

          def to_prompt
            {
              messages: Gitlab::Llm::Chain::Utils::Prompt.role_conversation(
                Gitlab::Llm::Chain::Utils::Prompt.format_conversation([USER_MESSAGE], variables)
              ),
              model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_7_SONNET
            }
          end

          def variables
            {
              diff: extracted_diff,
              description: params[:description],
              title: params[:title],
              user_prompt: params[:user_prompt],
              previous_response: params[:previous_response] || ''
            }
          end

          private

          attr_reader :user, :project, :params

          def extracted_diff
            Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
              source_project: source_project,
              source_branch: params[:source_branch],
              target_project: project,
              target_branch: params[:target_branch],
              character_limit: 10000
            )
          end
          strong_memoize_attr :extracted_diff

          def source_project
            return project unless params[:source_project_id]

            source_project = Project.find_by_id(params[:source_project_id])

            return source_project if source_project.present? && user.can?(:create_merge_request_from, source_project)

            project
          end
        end
      end
    end
  end
end
