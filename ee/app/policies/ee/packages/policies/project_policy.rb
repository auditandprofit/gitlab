# frozen_string_literal: true

module EE
  module Packages
    module Policies
      module ProjectPolicy
        extend ActiveSupport::Concern

        prepended do
          rule { project.ip_enforcement_prevents_access & ~admin & ~auditor }.policy do
            prevent :read_package
            prevent :create_package
            prevent :update_package
            prevent :admin_package
            prevent :destroy_package
          end
        end
      end
    end
  end
end
