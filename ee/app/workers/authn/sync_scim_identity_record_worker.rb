# frozen_string_literal: true

module Authn
  class SyncScimIdentityRecordWorker
    include ApplicationWorker

    data_consistency :sticky
    feature_category :system_access

    idempotent!
    def perform(args)
      scim_identity = ScimIdentity.find_by(id: args['scim_identity_id']) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing
      return if scim_identity.blank? || scim_identity.group.blank?

      group_scim_identity = GroupScimIdentity.find_by(temp_source_id: scim_identity.id) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing
      return if group_scim_identity && (group_scim_identity.updated_at >= scim_identity.updated_at)

      group_scim_identity ||= GroupScimIdentity.find_or_initialize_by( # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing
        user: scim_identity.user, group: scim_identity.group)
      group_scim_identity.assign_attributes(
        temp_source_id: scim_identity.id,
        extern_uid: scim_identity.extern_uid,
        created_at: scim_identity.created_at,
        updated_at: scim_identity.updated_at,
        user: scim_identity.user,
        group: scim_identity.group,
        active: scim_identity.active
      )
      group_scim_identity.save!
    end
  end
end
