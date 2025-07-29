# frozen_string_literal: true

module WorkItems
  module DataSync
    module Widgets
      class HealthStatus < Base
        def after_save_commit
          # copy HealthStatus
        end

        def post_move_cleanup
          # do it
        end
      end
    end
  end
end
