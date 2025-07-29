# frozen_string_literal: true

module EE
  module Ci
    module Queue
      module PendingBuildsStrategy
        extend ActiveSupport::Concern

        def enforce_minutes_limit(relation)
          relation.with_ci_minutes_available
        end

        def enforce_allowed_plan_ids(relation, allowed_plan_ids)
          relation.with_allowed_plan_ids(allowed_plan_ids)
        end
      end
    end
  end
end
