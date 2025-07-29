# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class CountGroupsDuoAvailabilityMetric < GenericMetric
          DUO_SETTINGS_VALUES = %w[default_on default_off never_on].freeze

          def initialize(metric_definition)
            super

            return if options[:duo_settings_value].in?(DUO_SETTINGS_VALUES)

            raise ArgumentError,
              "Unknown parameters: duo_settings_value:#{options[:duo_settings_value]}"
          end

          def value
            Group.joins(:namespace_settings)
              .where(namespace_settings: duo_settings_to_settings_filter(options[:duo_settings_value])).count
          end

          private

          def duo_settings_to_settings_filter(duo_settings_value)
            # The default_off scenario will have both values set to false and is assigned implicitly
            {
              duo_features_enabled: duo_settings_value == 'default_on',
              lock_duo_features_enabled: duo_settings_value == 'never_on'
            }
          end
        end
      end
    end
  end
end
