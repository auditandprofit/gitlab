# frozen_string_literal: true

module EE
  module Mutations
    module Groups
      module Update
        extend ActiveSupport::Concern

        prepended do
          argument :duo_features_enabled, GraphQL::Types::Boolean,
            required: false,
            description: copy_field_description(::Types::GroupType, :duo_features_enabled)
          argument :lock_duo_features_enabled, GraphQL::Types::Boolean,
            required: false,
            description: copy_field_description(::Types::GroupType, :lock_duo_features_enabled)
          argument :web_based_commit_signing_enabled,
            GraphQL::Types::Boolean,
            required: false,
            description: copy_field_description(::Types::GroupType, :web_based_commit_signing_enabled),
            experiment: { milestone: '18.2' }
        end
      end
    end
  end
end
