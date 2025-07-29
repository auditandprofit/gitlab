# frozen_string_literal: true

class GroupScimIdentity < ApplicationRecord # rubocop:disable Gitlab/NamespacedClass,Gitlab/BoundedContexts -- Split from existing file
  include Sortable
  include CaseSensitivity
  include ScimPaginatable

  belongs_to :group
  belongs_to :user

  validates :user, presence: true, uniqueness: { scope: [:group_id] }
  validates :extern_uid, presence: true,
    uniqueness: { case_sensitive: false, scope: [:group_id] }

  scope :for_user, ->(user) { where(user: user) }
  scope :with_extern_uid, ->(extern_uid) { iwhere(extern_uid: extern_uid) }

  after_commit :sync_records, on: %i[create update]

  def sync_records
    Authn::SyncGroupScimIdentityRecordWorker.perform_async({ 'group_scim_identity_id' => id })
  end
end
