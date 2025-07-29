# frozen_string_literal: true

module API
  module Entities
    module Admin
      module Security
        class PolicySetting < Grape::Entity
          expose :csp_namespace_id
        end
      end
    end
  end
end
