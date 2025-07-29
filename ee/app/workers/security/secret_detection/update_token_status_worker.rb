# frozen_string_literal: true

# Worker for creating and updating token status records for findings from security scans.
#
# This worker processes secret detection findings from a pipeline and creates
# or updates FindingTokenStatus records that indicate whether detected tokens
# match known personal access tokens and their current status.
#
module Security
  module SecretDetection
    class UpdateTokenStatusWorker
      include ApplicationWorker

      feature_category :secret_detection
      data_consistency :sticky

      idempotent!

      concurrency_limit -> { 20 }

      # Creates or updates FindingTokenStatus records for secret detection findings in a pipeline.
      #
      # @param [Integer] pipeline_id ID of the pipeline containing security scan results
      def perform(pipeline_id)
        Security::SecretDetection::UpdateTokenStatusService.new.execute_for_pipeline(pipeline_id)
      end
    end
  end
end
