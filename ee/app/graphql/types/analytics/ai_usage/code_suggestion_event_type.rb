# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      # rubocop: disable Graphql/AuthorizeTypes -- authorized with parent object type
      class CodeSuggestionEventType < BaseObject
        graphql_name 'CodeSuggestionEvent'

        field :id, GraphQL::Types::ID,
          null: false, description: "ID of the code suggestion event."

        field :timestamp,
          Types::TimeType,
          null: false,
          description: 'When the event happened.'

        field :event,
          CodeSuggestionEventEnum,
          null: false,
          description: 'Type of the event.'

        field :user,
          Types::UserType,
          null: false,
          description: 'User associated with the event.'

        field :language,
          GraphQL::Types::String,
          null: true,
          description: 'Programming language in the context of the suggestion.'

        field :suggestion_size,
          GraphQL::Types::String,
          null: true,
          description: 'Size of the code suggestion measured in lines of code.'

        field :unique_tracking_id,
          GraphQL::Types::String,
          null: true,
          description: 'Unique tracking number of sequence of events for one suggestion.'

        def payload
          @payload ||= object.payload || {}
        end

        def language
          payload['language']
        end

        def suggestion_size
          payload['suggestion_size']
        end

        def unique_tracking_id
          payload['unique_tracking_id']
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
