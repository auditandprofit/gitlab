# frozen_string_literal: true

module EE
  module Packages
    module Policies
      module GroupPolicy
        extend ActiveSupport::Concern

        prepended do
          rule { group.ip_enforcement_prevents_access & ~group.owner }.policy do
            prevent :read_package
            prevent :create_package
            prevent :update_package
            prevent :admin_package
            prevent :destroy_package
          end

          rule { group.auditor }.policy do
            enable :read_package
          end
        end
      end
    end
  end
end
