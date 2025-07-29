# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module Entry
        module GitlabSecretsManager
          class Secret < ::Gitlab::Config::Entry::Node
            include ::Gitlab::Config::Entry::Validatable
            include ::Gitlab::Config::Entry::Attributable

            ALLOWED_KEYS = %i[name].freeze

            attributes ALLOWED_KEYS

            validations do
              validates :config, type: Hash
              validates :name, presence: true, type: String
            end

            def value
              {
                name: name
              }
            end
          end
        end
      end
    end
  end
end
