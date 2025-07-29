# frozen_string_literal: true

module Epics
  class BaseService < IssuableBaseService
    extend ::Gitlab::Utils::Override

    def self.constructor_container_arg(value)
      # TODO: Dynamically determining the type of a constructor arg based on the class is an antipattern,
      # but the root cause is that Epics::BaseService has some issues that inheritance may not be the
      # appropriate pattern. See more details in comments at the top of Epics::BaseService#initialize.
      # Follow on issue to address this:
      # https://gitlab.com/gitlab-org/gitlab/-/issues/328438

      { group: value }
    end

    attr_reader :parent_epic, :child_epic, :remove_parent

    # TODO: The first argument of the initializer is named group because it has no `project` associated,
    # even though it is only a `group` in this sub-hierarchy of `IssuableBaseClass`,
    # but is a `project` everywhere else.  This is because named arguments
    # were added after the class was already in use. We use `.constructor_container_arg`
    # to determine the correct keyword to use.
    #
    # This is revealing an inconsistency which already existed,
    # where sometimes a `project` is passed as the first argument but ignored.  For example,
    # in `IssuableBaseService#change_state` method, as well as many others.
    #
    # This is a form of violation of the Liskov Substitution Principle
    # (https://en.wikipedia.org/wiki/Liskov_substitution_principle),
    # in that we cannot determine which form of the constructor to call without
    # knowing what the type of subclass is.
    #
    # This implies that inheritance may not be the proper relationship to "issuable",
    # because it may not be an "is a" relationship.
    #
    # All other `IssuableBaseService` subclasses are in the context of a
    # project, and take the project as the first argument to the constructor.
    #
    # Instead, is seems like there is are some concerns such as state management, and
    # having notes, which are applicable to "epic" services, but not necessarily all aspects
    # of "issuable" services.
    #
    # See the following links for more context:
    # - Original discussion thread: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/59182#note_555401711
    # - Issue to address inheritance problems: https://gitlab.com/gitlab-org/gitlab/-/issues/328438
    def initialize(group:, current_user:, params: {})
      super(container: group, current_user: current_user, params: params)
    end

    private

    override :available_callbacks
    def available_callbacks
      [
        Issuable::Callbacks::Description,
        Issuable::Callbacks::Labels
      ].freeze
    end

    override :handle_quick_actions
    def handle_quick_actions(epic)
      super

      set_quick_action_params
    end

    override :filter_params
    def filter_params(epic)
      filter_parent_epic

      super
    end

    def set_quick_action_params
      @parent_epic = params.delete(:quick_action_assign_to_parent_epic)
      @child_epic = params.delete(:quick_action_assign_child_epic)
    end

    def assign_parent_epic_for(epic)
      return unless parent_epic

      result = ::WorkItems::LegacyEpics::EpicLinks::CreateService.new(parent_epic, current_user,
        { target_issuable: epic }).execute

      handle_epic_parent_updated(epic, result)
    end

    def assign_child_epic_for(epic)
      return unless child_epic

      result = ::WorkItems::LegacyEpics::EpicLinks::CreateService.new(epic, current_user,
        { target_issuable: child_epic }).execute

      handle_epic_parent_updated(epic, result)
    end

    def handle_epic_parent_updated(epic, result)
      if result[:status] == :error
        epic.errors.add(:base, result[:message])
      else
        # It's not setting the parent on the record, since we use the WorkItem service underneath.
        # With Rails 7.1.x we could use `reset_parent` to be more specific.
        epic.reset
        track_epic_parent_updated
      end

      result
    end

    def remove_parent_epic_for(epic)
      return unless remove_parent && epic.parent

      result = Epics::EpicLinks::DestroyService.new(epic, current_user).execute
      return if result[:status] == :error

      track_epic_parent_updated
    end

    def available_labels
      @available_labels ||= LabelsFinder.new(
        current_user,
        group_id: group.id,
        only_group_labels: true,
        include_ancestor_groups: true
      ).execute
    end

    def parent
      group
    end

    def track_epic_parent_updated
      ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_parent_updated_action(
        author: current_user,
        namespace: group
      )
    end

    def filter_parent_epic
      return unless params.key?(:parent) || params.key?(:parent_id)

      @parent_epic = if params.key?(:parent)
                       @remove_parent = true if params[:parent].nil?
                       params.delete(:parent)
                     elsif params.key?(:parent_id)
                       Epic.find_by_id(params[:parent_id])
                     end

      params.delete(:parent_id)
    end

    def log_audit_event(epic, event_type, message)
      audit_context = {
        name: event_type,
        author: current_user,
        scope: epic.group,
        target: epic,
        message: message,
        target_details: { iid: epic.iid, id: epic.id }
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end
  end
end
