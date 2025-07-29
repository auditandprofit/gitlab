# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoSettings
      class DuoSettingsResolver < BaseResolver
        type ::Types::Ai::DuoSettings::DuoSettingsType, null: false

        def resolve
          ::Ai::Setting.instance
        end
      end
    end
  end
end
