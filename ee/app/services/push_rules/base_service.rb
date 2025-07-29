# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
module PushRules
  class BaseService < BaseContainerService
    attr_reader :organization

    def organization_container?
      container.is_a?(::Organizations::Organization)
    end

    private

    def handle_container_type(container)
      super

      @organization = container if container.is_a?(Organizations::Organization)
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
