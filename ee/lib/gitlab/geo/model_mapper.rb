# frozen_string_literal: true

module Gitlab
  module Geo
    # Finds a Model class associated with a String, which can be a parameter received by a controller
    # The string needs to match the model name, as defined by the Replicators
    #
    # Examples:
    # find_from_name("packages_package_file") returns Packages::PackageFile
    # convert_to_name(Packages::PackageFile) returns "packages_package_file"
    class ModelMapper
      class << self
        include Gitlab::Utils::StrongMemoize

        # Used by the Replicator to format a model name for API usage
        # @return [String] the snake_case representation of the passed Model class
        def convert_to_name(model)
          model_name_converter(model)
        end

        # Used by the controller to get an ActiveRecord model from a passed parameter
        # @return [Class] the Model class matching the passed string, or nil
        def find_from_name(model_name)
          return unless model_name.is_a?(String)

          model_matching_hash[model_name.downcase]
        end

        def available_models
          list_of_available_models
        end

        private

        def model_matching_hash
          list_of_available_models.index_by { |model| model_name_converter(model) }
        end
        strong_memoize_attr :model_matching_hash

        def list_of_available_models
          Gitlab::Geo::Replicator.subclasses.map(&:model)
        end
        strong_memoize_attr :list_of_available_models

        def model_name_converter(model_class)
          ::Gitlab::Utils.param_key(model_class)
        end
      end
    end
  end
end
