# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module AuditEventStreamingDestinations
        class Create < Base
          graphql_name 'InstanceAuditEventStreamingDestinationsCreate'
          include ::AuditEvents::StreamDestinationSyncHelper

          argument :config, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- Different type of destinations will have different configs
            required: true,
            description: 'Destination config.'

          argument :name, GraphQL::Types::String,
            required: false,
            description: 'Destination name.'

          argument :category, GraphQL::Types::String,
            required: true,
            description: 'Destination category.'

          argument :secret_token, GraphQL::Types::String,
            required: false,
            description: 'Secret token.'

          field :external_audit_event_destination, ::Types::AuditEvents::Instance::StreamingDestinationType,
            null: true,
            description: 'Destination created.'

          def resolve(secret_token: nil, name: nil, category: nil, config: nil)
            unless validate_secret_token(category, secret_token)
              return {
                errors: ["Secret token is required for category"]
              }
            end

            destination = ::AuditEvents::Instance::ExternalStreamingDestination.new(secret_token: secret_token,
              name: name,
              config: config,
              category: category
            )

            audit(destination, action: :created) if destination.save

            create_legacy_destination(destination)

            {
              external_audit_event_destination: (destination if destination.persisted?),
              errors: Array(destination.errors)
            }
          end

          private

          def validate_secret_token(category, secret_token)
            category == 'http' || secret_token.present?
          end
        end
      end
    end
  end
end
