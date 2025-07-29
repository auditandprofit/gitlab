# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- the PermissionTypes::Group already exists in CE, this is just the EE extension
module EE
  module Types
    module PermissionTypes
      module Group
        extend ActiveSupport::Concern

        prepended do
          ability_field :generate_description
        end
      end
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
