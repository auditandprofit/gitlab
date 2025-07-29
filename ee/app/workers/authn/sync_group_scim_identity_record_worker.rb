# frozen_string_literal: true

module Authn
  class SyncGroupScimIdentityRecordWorker
    include ApplicationWorker

    data_consistency :sticky
    feature_category :system_access

    idempotent!

    def perform(args = {})
      group_scim_identity = GroupScimIdentity.find_by(id: args['group_scim_identity_id']) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing
      return if group_scim_identity.blank?

      scim_identity = ScimIdentity.find_by(id: group_scim_identity.temp_source_id) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing
      return if scim_identity && (scim_identity.updated_at >= group_scim_identity.updated_at)

      scim_identity ||= ScimIdentity.find_or_initialize_by( # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing
        user: group_scim_identity.user, group: group_scim_identity.group
      )
      scim_identity.assign_attributes(
        extern_uid: group_scim_identity.extern_uid,
        created_at: group_scim_identity.created_at,
        updated_at: group_scim_identity.updated_at,
        user: group_scim_identity.user,
        group: group_scim_identity.group,
        active: group_scim_identity.active
      )
      scim_identity.save!
      group_scim_identity.update_column(:temp_source_id, scim_identity.id)
    end
  end
end
