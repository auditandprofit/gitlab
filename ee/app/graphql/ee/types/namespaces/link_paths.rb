# frozen_string_literal: true

module EE
  module Types
    module Namespaces
      module LinkPaths
        extend ActiveSupport::Concern

        prepended do
          field :epics_list,
            GraphQL::Types::String,
            null: true,
            description: 'Namespace epics_list.',
            fallback_value: nil

          field :group_issues,
            GraphQL::Types::String,
            null: true,
            description: 'Namespace group_issues.',
            fallback_value: nil

          field :labels_fetch,
            GraphQL::Types::String,
            null: true,
            description: 'Namespace labels_fetch.',
            fallback_value: nil
        end
      end
    end
  end
end
