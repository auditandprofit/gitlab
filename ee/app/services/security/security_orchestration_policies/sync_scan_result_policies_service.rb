# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncScanResultPoliciesService
      def initialize(configuration)
        @configuration = configuration
        @sync_project_service = SyncScanResultPoliciesProjectService.new(configuration)
      end

      def execute
        measure(:gitlab_security_policies_update_configuration_duration_seconds) do
          delay = 0
          configuration.all_project_ids do |project_ids|
            project_ids.each do |project_id|
              @sync_project_service.execute(project_id, { delay: delay })
            end

            delay += 10.seconds
          end
        end
      end

      private

      attr_reader :configuration

      delegate :measure, to: ::Security::SecurityOrchestrationPolicies::ObserveHistogramsService
    end
  end
end
