# frozen_string_literal: true

module EE
  module API
    module Entities
      class AuditEvent < Grape::Entity
        expose :id
        expose :author_id
        expose :entity_id
        expose :entity_type
        expose :event_name do |audit_event|
          audit_event.details.fetch :event_name, nil
        end
        expose :details do |audit_event|
          audit_event.formatted_details
        end
        expose :created_at
      end
    end
  end
end
