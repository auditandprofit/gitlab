# frozen_string_literal: true

module Types
  module Members
    module CustomizablePermission
      extend ActiveSupport::Concern

      included do
        def self.define_permission(name, attrs, feature_flag: nil)
          if CustomizablePermission.experimental?(name, feature_flag: feature_flag)
            value name.upcase, value: name, description: attrs[:description],
              experiment: { milestone: attrs[:milestone] }
          else
            value name.upcase, value: name, description: attrs[:description]
          end
        end
      end

      # As new custom abilities are created they are implemented behind a feature flag with a standard
      # naming convention. Since these abilities depend on the feature flag being enabled, we want to mark
      # any feature flagged abilities as experimental until they are generally released.
      #
      # Optionally, an additional feature flag parameter can be passed to check a feature flag that is meant
      # to mark many custom permissions as experimental at once.
      def self.experimental?(permission, feature_flag: nil)
        ["custom_ability_#{permission}", feature_flag].compact.any? do |ff|
          ::Feature::Definition.get(ff)
        end
      end
    end
  end
end
