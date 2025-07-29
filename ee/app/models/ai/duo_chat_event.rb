# frozen_string_literal: true

module Ai
  class DuoChatEvent < ApplicationRecord
    include EachBatch
    include BaseUsageEvent

    self.table_name = "ai_duo_chat_events"
    self.clickhouse_table_name = "duo_chat_events"

    enum :event, { request_duo_chat_response: 1 }

    validates :organization_id, :personal_namespace_id, presence: true

    populate_sharding_key(:organization_id) { Gitlab::Current::Organization.new(user: user).organization&.id }

    before_validation :populate_legacy_sharding_key

    private

    def populate_legacy_sharding_key
      self.personal_namespace_id = user.namespace_id if user
    end
  end
end
