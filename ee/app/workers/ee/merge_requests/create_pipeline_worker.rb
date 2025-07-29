# frozen_string_literal: true

module EE
  module MergeRequests
    module CreatePipelineWorker
      extend ::Gitlab::Utils::Override

      override :after_perform
      def after_perform(merge_request)
        # MR pipelines are created asynchronously *after* their MR is updated.
        # At this point the MR was updated and it either has a pipeline or
        # it won't for its current HEAD.
        #
        # If the MR has a pipeline, then the MR's fail-open approval policy
        # rules will be unblocked after pipeline completion.
        return if merge_request.diff_head_pipeline

        return unless merge_request.project.licensed_feature_available?(:security_orchestration_policies)

        # If the MR has no pipeline, unblock its fail-open rules right away.
        ::Security::ScanResultPolicies::UnblockFailOpenApprovalRulesWorker.perform_async(merge_request.id)
      end
    end
  end
end
