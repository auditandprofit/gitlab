# frozen_string_literal: true

module RemoteDevelopment
  class WorkspaceVariable < ApplicationRecord
    include Sortable
    include Enums::WorkspaceVariable
    include Gitlab::EncryptedAttribute

    belongs_to :workspace, class_name: 'RemoteDevelopment::Workspace', inverse_of: :workspace_variables

    validates :variable_type, presence: true, inclusion: { in: WORKSPACE_VARIABLE_TYPES.values }
    validates :encrypted_value, presence: true
    validates :key,
      presence: true,
      format: { with: /\A[a-zA-Z0-9\-_.]+\z/, message: 'must contain only alphanumeric characters, -, _ or .' },
      length: { maximum: 255 }

    scope :with_variable_type_environment, -> { where(variable_type: ENVIRONMENT_TYPE) }
    scope :with_variable_type_file, -> { where(variable_type: FILE_TYPE) }

    scope :by_workspace_ids, ->(ids) { where(workspace_id: ids) }
    scope :by_project_ids, ->(ids) { where(project_id: ids) }

    scope :user_provided, -> {
      where(user_provided: true)
    }

    attr_encrypted :value, # rubocop:disable Gitlab/Rails/AttrEncrypted -- https://gitlab.com/gitlab-org/gitlab/-/issues/525574
      mode: :per_attribute_iv,
      key: :db_key_base_32,
      algorithm: 'aes-256-gcm',
      allow_empty_value: true
  end
end
