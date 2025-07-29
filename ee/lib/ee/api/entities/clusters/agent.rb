# frozen_string_literal: true

module EE
  module API
    module Entities
      module Clusters
        module Agent
          extend ActiveSupport::Concern

          prepended do
            expose :is_receptive
          end
        end
      end
    end
  end
end
