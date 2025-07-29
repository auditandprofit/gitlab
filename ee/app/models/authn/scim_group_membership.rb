# frozen_string_literal: true

module Authn
  class ScimGroupMembership < ApplicationRecord
    include BulkInsertSafe

    self.table_name = 'scim_group_memberships'

    belongs_to :user, optional: false

    validates :scim_group_uid, presence: true
    validates :user, uniqueness: { scope: :scim_group_uid }

    scope :by_scim_group_uid, ->(scim_group_uid) { where(scim_group_uid: scim_group_uid) }
    scope :by_user_id, ->(user_id) { where(user_id: user_id) }
    scope :excluding_scim_group_uid, ->(scim_group_uid) { where.not(scim_group_uid: scim_group_uid) }

    def self.user_ids_to_remove_for_replace(scim_group_uid, target_user_ids)
      by_scim_group_uid(scim_group_uid).where.not(user_id: target_user_ids).select(:user_id)
    end
  end
end
