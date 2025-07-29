# frozen_string_literal: true

module Authn
  class SyncGroupScimTokenRecordWorker
    include ApplicationWorker

    data_consistency :sticky
    feature_category :system_access

    idempotent!

    def perform(args)
      group_scim_token = GroupScimAuthAccessToken.find_by(id: args['group_scim_token_id']) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing

      return if group_scim_token.blank?

      scim_token = ScimOauthAccessToken.find_by(id: group_scim_token.temp_source_id) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing

      scim_token ||= ScimOauthAccessToken.find_by(group: group_scim_token.group) # rubocop:disable CodeReuse/ActiveRecord -- temporary worker for the purpose of syncing

      return if scim_token && scim_token.updated_at >= group_scim_token.updated_at

      scim_token ||= ScimOauthAccessToken.new

      scim_token.assign_attributes(
        token_encrypted: group_scim_token.token_encrypted,
        group: group_scim_token.group,
        updated_at: group_scim_token.updated_at
      )
      scim_token.save!
    end
  end
end
