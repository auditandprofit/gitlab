# frozen_string_literal: true

class ScimOauthAccessToken < ApplicationRecord
  include TokenAuthenticatable

  TOKEN_PREFIX = 'glsoat-'

  belongs_to :group, optional: true

  add_authentication_token_field :token, encrypted: :required, format_with_prefix: :prefix_for_token

  before_save :ensure_token

  after_commit :sync_records, on: %i[create update]

  def self.token_matches_for_group?(token, group)
    # Necessary to call `Authn::TokenField::Encrypted.find_token_authenticatable`
    token = find_by_token(token)

    token && group && token.group_id == group.id
  end

  def self.token_matches_for_instance?(token)
    # Necessary to call `Authn::TokenField::Encrypted.find_token_authenticatable`
    token = find_by_token(token)
    # This method is for authenticating with instance-level SCIM tokens. As a
    # result, group SCIM tokens should return falsey value
    token && !token.group_id
  end

  def self.find_for_instance
    find_by_group_id(nil)
  end

  def as_entity_json
    ScimOauthAccessTokenEntity.new(self).as_json
  end

  def prefix_for_token
    TOKEN_PREFIX
  end

  def sync_records
    Authn::SyncScimTokenRecordWorker.perform_async({ 'group_scim_token_id' => id })
  end
end
