# frozen_string_literal: true

module EE
  module Types
    module Ci
      module CiCdSettingType
        extend ActiveSupport::Concern

        prepended do
          field :merge_trains_skip_train_allowed,
            GraphQL::Types::Boolean,
            null: false,
            description: 'Whether merge immediately is allowed for merge trains.',
            method: :merge_trains_skip_train_allowed?,
            authorize: :admin_project
          field :merge_trains_enabled,
            GraphQL::Types::Boolean,
            null: true,
            description: 'Whether merge trains are enabled.',
            method: :merge_trains_enabled?
        end
      end
    end
  end
end
