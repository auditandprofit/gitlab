# frozen_string_literal: true

module API
  module Ai
    module Llm
      class GitCommand < ::API::Base
        feature_category :code_review_workflow
        urgency :low

        before do
          authenticate!
          check_rate_limit!(:ai_action, scope: [current_user])
        end

        namespace 'ai/llm' do
          desc 'Generates Git commands from natural text'
          params do
            requires :prompt, type: String
          end

          post 'git_command' do
            response = ::Llm::GitCommandService.new(current_user, current_user, declared_params).execute

            if response.success?
              response.payload
            else
              bad_request!(response.message)
            end
          end
        end
      end
    end
  end
end
