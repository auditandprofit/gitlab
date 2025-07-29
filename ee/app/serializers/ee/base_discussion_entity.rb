# frozen_string_literal: true

module EE
  module BaseDiscussionEntity
    extend ::Gitlab::Utils::Override

    private

    override :truncated_discussion_path_for
    def truncated_discussion_path_for(discussion)
      noteable = discussion.noteable
      return discussions_group_epic_path(noteable.namespace, noteable) if epic_noteable?(noteable)

      super
    end

    def epic_noteable?(noteable)
      noteable.try(:work_item_type) == ::WorkItems::Type.default_by_type(:epic)
    end
  end
end
