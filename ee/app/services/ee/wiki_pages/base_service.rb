# frozen_string_literal: true

module EE
  module WikiPages
    # BaseService EE mixin
    #
    # This module is intended to encapsulate EE-specific service logic
    # and be included in the `WikiPages::BaseService` service
    module BaseService
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :increment_usage
      def increment_usage(page)
        super

        track_event(page, group_internal_event_name) if namespace_container?
      end

      override :execute_hooks
      def execute_hooks(page)
        super
        process_wiki_repository_update
      end

      def process_wiki_repository_update
        # TODO: Geo support for group wiki https://gitlab.com/gitlab-org/gitlab/-/issues/208147
        return unless container.is_a?(Project)

        container.wiki_repository.geo_handle_after_update if container.wiki_repository
      end
    end
  end
end
