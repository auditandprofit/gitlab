# frozen_string_literal: true

module EE
  # This module is intended to encapsulate EE-specific model logic and be
  # prepended in the `Repositories::PostReceiveWorker`
  module Repositories
    module PostReceiveWorker
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      # rubocop:disable Gitlab/NoCodeCoverageComment -- undercoverage false positive, tested in ee/spec/workers/post_receive_worker_spec.rb
      # :nocov:
      def after_project_changes_hooks(project, user, refs, changes)
        super

        return unless ::Gitlab::Geo.primary?

        project.geo_handle_after_update
      end
      # :nocov:
      # rubocop:enable Gitlab/NoCodeCoverageComment

      def process_wiki_changes(post_received, wiki)
        super

        if wiki.is_a?(ProjectWiki)
          process_project_wiki_changes(wiki)
        else
          process_group_wiki_changes(wiki)
        end
      end

      def process_project_wiki_changes(wiki)
        project_wiki_repository = wiki.project.wiki_repository
        project_wiki_repository.geo_handle_after_update if project_wiki_repository
      end

      def process_group_wiki_changes(wiki)
        return unless wiki.group.group_wiki_repository

        wiki.group.group_wiki_repository.geo_handle_after_update
      end

      override :replicate_snippet_changes
      # rubocop:disable Gitlab/NoCodeCoverageComment -- https://gitlab.com/gitlab-org/gitlab/-/issues/512940
      # :nocov:
      def replicate_snippet_changes(snippet)
        return unless ::Gitlab::Geo.primary?

        snippet.snippet_repository.geo_handle_after_update if snippet.snippet_repository
      end
      # :nocov:
      # rubocop:enable Gitlab/NoCodeCoverageComment
      override :replicate_design_management_repository_changes
      def replicate_design_management_repository_changes(design_management_repository)
        design_management_repository.geo_handle_after_update if design_management_repository
      end
    end
  end
end
