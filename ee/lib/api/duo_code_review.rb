# frozen_string_literal: true

module API
  class DuoCodeReview < ::API::Base
    include APIGuard

    feature_category :code_review_workflow

    allow_access_with_scope :ai_features

    before do
      not_found! unless Gitlab.dev_or_test_env?

      authenticate!

      license_feature_available = ::License.feature_available?(:review_merge_request)
      global_feature_flag_enabled = Gitlab::Llm::Utils::FlagChecker.flag_enabled_for_feature?(:review_merge_request)

      not_found! unless license_feature_available && global_feature_flag_enabled
    end

    helpers do
      def parse_raw_diffs(raw_diffs)
        diffs = {}
        current_file = nil
        current_content = []

        raw_diffs.each_line do |line|
          if line.start_with?('diff --git ')
            # Save the previous file's content
            if current_file && !current_content.empty?
              diffs[current_file] = current_content.join
              current_content = []
            end

            # Extract the new file path
            match = line.match(%r{diff --git a/.+ b/(.+)})
            current_file = match[1] if match

            # Start collecting content for this file
            current_content << line
          elsif current_file
            # Add line to current file's content
            current_content << line
          end
        end

        # Add the last file's content
        diffs[current_file] = current_content.join if current_file && !current_content.empty?
        diffs
      end
    end

    namespace 'duo_code_review' do
      resources :evaluations do
        params do
          requires :diffs, type: String, desc: 'Raw diffs to review'
          requires :mr_title, type: String, desc: 'Title of the merge request'
          requires :mr_description, type: String, desc: 'Description of the merge request'
          requires :file_contents, type: Hash,
            desc: 'Full file contents, where keys are file paths and values are the file contents'
        end

        post do
          # Parse the raw diffs to extract individual files
          diffs_and_paths = parse_raw_diffs(declared_params[:diffs])

          prompt = ::Gitlab::Llm::Templates::ReviewMergeRequest
            .new(
              mr_title: declared_params[:mr_title],
              mr_description: declared_params[:mr_description],
              diffs_and_paths: diffs_and_paths,
              files_content: declared_params[:file_contents],
              user: current_user
            )
            .to_prompt

          response = ::Gitlab::Llm::Anthropic::Client.new(
            current_user,
            unit_primitive: 'review_merge_request'
          ).messages_complete(**prompt)

          response_modifier = ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)

          review_response = { review: response_modifier.response_body }

          present review_response, with: Grape::Presenters::Presenter
        end
      end
    end
  end
end
