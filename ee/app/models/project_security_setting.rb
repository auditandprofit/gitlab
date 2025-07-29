# frozen_string_literal: true

class ProjectSecuritySetting < ApplicationRecord
  self.primary_key = :project_id

  belongs_to :project, inverse_of: :security_setting
  validates :license_configuration_source, presence: true

  enum :license_configuration_source, ::Enums::Security.configuration_source_types, suffix: true

  scope :for_projects, ->(project_ids) { where(project_id: project_ids) }

  ignore_column :pre_receive_secret_detection_enabled, remove_with: '17.9', remove_after: '2025-02-15'

  # saved_change_to_project_id? will return true on creating a new instance as project_id is the primary key
  after_commit -> { schedule_analyzer_status_update_worker_for_type('container_scanning') },
    if: -> { saved_change_to_container_scanning_for_registry_enabled? || saved_change_to_project_id? }

  after_commit -> { schedule_analyzer_status_update_worker_for_type('secret_detection') },
    if: -> { saved_change_to_secret_push_protection_enabled? || saved_change_to_project_id? }

  def set_continuous_vulnerability_scans!(enabled:)
    enabled if update!(continuous_vulnerability_scans_enabled: enabled)
  end

  def set_container_scanning_for_registry!(enabled:)
    enabled if update!(container_scanning_for_registry_enabled: enabled)
  end

  def set_secret_push_protection!(enabled:)
    enabled if update!(secret_push_protection_enabled: enabled)
  end

  def set_validity_checks!(enabled:)
    enabled if update!(validity_checks_enabled: enabled)
  end

  private

  def schedule_analyzer_status_update_worker_for_type(type)
    Security::AnalyzersStatus::SettingChangedUpdateWorker.perform_async([project_id], type)
  end
end
