# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class AnalyzePipelineExecutionPolicyConfigService < BaseProjectService
      def execute
        content = YAML.dump(params[:content])
        config = Gitlab::Ci::Config.new(content, project: project, user: current_user)

        unless config.valid?
          return ServiceResponse.error(
            message: "Error occurred while parsing the CI configuration: #{config.errors}",
            payload: []
          )
        end

        analyzers_config = extract_analyzers_from_config(config.to_hash)
        scans = analyzers_config.keys & Security::MergeRequestSecurityReportGenerationService::ALLOWED_REPORT_TYPES
        ServiceResponse.success(payload: scans)
      rescue StandardError => e
        ServiceResponse.error(message: e.message, payload: [])
      end

      private

      def extract_analyzers_from_config(config)
        artifact_reports = config.select { |_key, entry| entry.is_a?(Hash) && entry[:artifacts].present? }
              .map { |_key, entry| entry.dig(:artifacts, :reports) }

        artifact_reports.each_with_object({}) do |reports, obj|
          reports.each do |report_type, path|
            obj[report_type] ||= Set.new
            obj[report_type] << path
          end
        end.with_indifferent_access
      end
    end
  end
end
