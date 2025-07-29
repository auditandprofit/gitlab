# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts, Gitlab/NamespacedClass -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
class GroupPushRule < ApplicationRecord
  include PushRuleable

  belongs_to :group

  def available?(feature_sym, _object: nil)
    group.licensed_feature_available?(feature_sym)
  end
end
# rubocop:enable Gitlab/BoundedContexts, Gitlab/NamespacedClass -- Will be decided on after https://gitlab.com/groups/gitlab-org/-/epics/16894 is finalized
