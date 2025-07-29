# frozen_string_literal: true

module Epics
  class EpicUpdatedEvent < Gitlab::EventStore::Event
    def schema
      {
        'type' => 'object',
        'required' => %w[id group_id],
        'properties' => { 'id' => { 'type' => 'integer' }, 'group_id' => { 'type' => 'integer' } }
      }
    end
  end
end
