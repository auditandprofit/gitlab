# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class DuoCoreFeaturesEnabledMetric < GenericMetric
          def value
            ::Ai::Setting.instance.duo_core_features_enabled
          end
        end
      end
    end
  end
end
