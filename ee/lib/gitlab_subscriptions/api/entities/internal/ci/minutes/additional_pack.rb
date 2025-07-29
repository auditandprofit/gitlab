# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Entities
      module Internal
        module Ci
          module Minutes
            class AdditionalPack < Grape::Entity
              expose :namespace_id, documentation: { type: 'string', example: 123 }
              expose :expires_at, documentation: { type: 'date', example: '2012-05-28' }
              expose :number_of_minutes, documentation: { type: 'integer', example: 10000 }
              expose :purchase_xid, documentation: { type: 'string', example: 'C-00123456' }
            end
          end
        end
      end
    end
  end
end
