# frozen_string_literal: true

module EE
  module Groups
    module BoardsController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_force_frontend_feature_flag(:work_item_epics, group.work_item_epics_enabled?)
        end
      end
    end
  end
end
