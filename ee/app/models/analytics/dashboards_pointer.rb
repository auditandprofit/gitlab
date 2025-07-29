# frozen_string_literal: true

module Analytics
  class DashboardsPointer < ApplicationRecord
    self.table_name = 'analytics_dashboards_pointers'

    belongs_to :namespace
    belongs_to :project
    belongs_to :target_project, optional: false, class_name: 'Project'

    validate :check_namespace_or_project_presence
    # Avoid breaking existing records. The read endpoint also "validates" (returns nil if invalid)
    # the presence of the target_project_id in the group hierarchy.
    validate :check_target_project_presence_in_hierarchy

    validates :namespace_id, uniqueness: { scope: :project_id }, if: :namespace_id?
    validates :project_id, uniqueness: { scope: :namespace_id }, if: :project_id?

    after_commit :send_new_funnels, on: :create
    after_commit :move_funnels, on: :update, if: :saved_change_to_target_project_id?
    after_commit :send_deleted_funnels, on: :destroy

    private

    def send_new_funnels
      ::ProductAnalytics::MoveFunnelsWorker.perform_async(project_id, nil, target_project_id)
    end

    def move_funnels
      ::ProductAnalytics::MoveFunnelsWorker.perform_async(project_id, previous_changes["target_project_id"].first,
        target_project_id)
    end

    def send_deleted_funnels
      ::ProductAnalytics::MoveFunnelsWorker.perform_async(project_id, target_project_id, nil)
    end

    def check_namespace_or_project_presence
      if !namespace_id && !project_id
        errors.add(:base, _('Namespace or project is required'))
      elsif namespace_id && project_id
        errors.add(:base, _('Only one source is required but both were provided'))
      end
    end

    def check_target_project_presence_in_hierarchy
      resource = project || namespace
      return if resource.nil?
      return if target_project_id.blank? || !target_project_id_changed?
      return if resource.root_ancestor.all_projects.exists?(id: target_project_id)

      errors.add(:base, _('The selected project is not available'))
    end
  end
end
