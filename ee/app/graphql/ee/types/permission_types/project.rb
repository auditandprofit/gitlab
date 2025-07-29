# frozen_string_literal: true

module EE
  module Types
    module PermissionTypes
      module Project
        extend ActiveSupport::Concern

        prepended do
          ability_field :read_path_locks
          ability_field :create_path_lock
          ability_field :admin_path_locks
          ability_field :generate_description
        end
      end
    end
  end
end
