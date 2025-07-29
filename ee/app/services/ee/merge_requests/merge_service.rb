# frozen_string_literal: true

module EE
  module MergeRequests
    module MergeService
      def after_merge
        MergeTrains::Car.insert_skip_merged_car_for(merge_request, current_user) if skipping_active_merge_train?

        super
      end

      def skipping_active_merge_train?
        params[:skip_merge_train] && project.merge_trains_skip_train_allowed?
      end
    end
  end
end
