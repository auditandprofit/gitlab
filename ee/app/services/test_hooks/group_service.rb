# frozen_string_literal: true

module TestHooks
  class GroupService < TestHooks::BaseService
    def execute
      project = @hook.group.first_non_empty_project

      return error('Ensure the group has a project with commits.') unless project

      service = TestHooks::ProjectService.new(hook, current_user, @trigger || 'push_events')
      service.project = project
      service.execute
    end
  end
end
