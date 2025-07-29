# frozen_string_literal: true

module EE
  module Types
    module WorkItemType # rubocop:disable Gitlab/BoundedContexts -- Types::WorkItemType is CE class
      extend ActiveSupport::Concern

      prepended do
        field :promoted_to_epic_url, GraphQL::Types::String, null: true,
          description: 'URL of the epic that the work item has been promoted to.'
      end
    end
  end
end
