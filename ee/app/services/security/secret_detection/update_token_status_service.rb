# frozen_string_literal: true

module Security
  module SecretDetection
    class UpdateTokenStatusService
      DEFAULT_BATCH_SIZE = 100

      attr_reader :project

      def initialize(token_lookup_service = TokenLookupService.new)
        @token_lookup_service = token_lookup_service
      end

      def execute_for_pipeline(pipeline_id)
        @pipeline = Ci::Pipeline.find_by_id(pipeline_id)
        @project = @pipeline&.project
        return unless @pipeline && can_run?(project)

        relation = Vulnerabilities::Finding.report_type('secret_detection').by_latest_pipeline(pipeline_id)

        relation.each_batch(of: DEFAULT_BATCH_SIZE) do |batch|
          process_findings_batch(batch)
        end
      end

      # Updates the token status for a single finding, identified by its ID.
      #
      # @param [Integer] finding_id The ID of the Vulnerabilities::Finding to update
      def execute_for_finding(finding_id)
        return unless finding_id

        finding = Vulnerabilities::Finding.find_by_id(finding_id)
        return unless finding

        @project = finding.project
        return unless can_run?(project)

        @pipeline = Ci::Pipeline.find_by_id(finding.latest_pipeline_id)

        process_findings_batch([finding])
      end

      private

      def can_run?(project)
        Feature.enabled?(:validity_checks, project) &&
          project.security_setting&.validity_checks_enabled
      end

      # Processes a batch of findings to create or update their FindingTokenStatus records.
      #
      # @param [ActiveRecord::Relation] findings A batch of Vulnerabilities::Finding records
      def process_findings_batch(findings)
        return if findings.empty?

        tokens_by_raw_token = get_tokens_by_raw_token_value(findings)

        token_status_attr_by_raw_token = build_token_status_attributes_by_raw_token(findings)

        # Set token status on token status attributes
        tokens_by_raw_token.each do |raw_token, token|
          token_status_attr_by_raw_token[raw_token].each do |finding_token_status_attr|
            finding_token_status_attr[:status] = token_status(token)
            finding_token_status_attr[:updated_at] = Time.current
          end
        end

        attributes_to_upsert = token_status_attr_by_raw_token.values.flatten
        return if attributes_to_upsert.empty?

        begin
          Vulnerabilities::FindingTokenStatus.upsert_all(attributes_to_upsert,
            unique_by: :vulnerability_occurrence_id,
            update_only: [:status, :updated_at],
            record_timestamps: false)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(
            e,
            pipeline_id: @pipeline&.id,
            project_id: project.id,
            finding_count: attributes_to_upsert.size
          )

          Gitlab::AppLogger.error(
            message: "Failed to upsert finding token statuses",
            exception: e.class.name,
            exception_message: e.message,
            pipeline_id: @pipeline&.id,
            project_id: project.id,
            finding_count: attributes_to_upsert.size
          )

          # Re-raise the exception to trigger Sidekiq retry mechanism
          raise
        end
      end

      # Retrieves token objects by their raw token values from findings
      #
      # @param findings [ActiveRecord::Relation] Secret detection findings containing token information
      # @return [Hash] A hash mapping raw token values to their corresponding token objects
      #
      # This method:
      # 1. Groups findings by token type (PAT, Deploy Token, etc.)
      # 2. Performs separate lookups for each token type using the appropriate lookup method
      # 3. Returns a combined hash of all found tokens indexed by their raw values
      def get_tokens_by_raw_token_value(findings)
        # organise detected tokens by type
        raw_token_values_by_token_type = findings.each_with_object({}) do |finding, result|
          finding_type = finding.token_type
          result[finding_type] = [] unless result[finding_type]
          result[finding_type] << finding.metadata['raw_source_code_extract']

          result
        end

        # Find tokens and index by raw token
        raw_token_values_by_token_type.each_with_object({}) do |(token_type, raw_token_values), result_hash|
          type_tokens = @token_lookup_service.find(token_type, raw_token_values)
          result_hash.merge!(type_tokens) if type_tokens
        rescue StandardError => e
          Gitlab::AppLogger.warn(
            message: "Failed to lookup tokens for type #{token_type}",
            exception: e.class.name,
            exception_message: e.message
          )
          next
        end
      end

      # Determines the appropriate status value for a FindingTokenStatus based on a personal access token.
      #
      # @param [PersonalAccessToken, nil] token The token to check, or nil if not found
      # @return [Symbol] Status enum value from FindingTokenStatus
      def token_status(token)
        statuses = Vulnerabilities::FindingTokenStatus.statuses

        return statuses.key(statuses[:unknown]) unless token

        if token.respond_to?(:active?)
          status_symbol = token.active? ? :active : :inactive
          return statuses.key(statuses[status_symbol])
        end

        # Tokens without active? method (e.g., GroupScimAuthAccessToken) are assumed to be active
        statuses.key(statuses[:active])
      end

      # Builds attributes for FindingTokenStatus records grouped by token SHA.
      #
      # @param [ActiveRecord::Relation] latest_secret_findings Secret detection findings
      # @return [Hash] A hash mapping token SHAs to arrays of FindingTokenStatus attributes
      def build_token_status_attributes_by_raw_token(findings)
        now = Time.current
        findings.each_with_object({}) do |finding, attr_by_raw_token|
          token_value = finding.metadata['raw_source_code_extract']

          next unless Security::SecretDetection::TokenLookupService.supported_token_type?(finding.token_type)

          attr_by_raw_token[token_value] ||= []
          attr_by_raw_token[token_value] << build_finding_token_status_attributes(finding, now)
        end
      end

      # Builds attributes for a single FindingTokenStatus record.
      #
      # @param [Vulnerabilities::Finding] finding The finding containing the token
      # @param [Time] time The timestamp to use for created_at and updated_at
      # @param [String] status Initial status to set (default: 'unknown')
      # @return [Hash] Attributes for creating a FindingTokenStatus record
      def build_finding_token_status_attributes(finding, time, status = 'unknown')
        {
          vulnerability_occurrence_id: finding.id,
          project_id: finding.project_id,
          status: status,
          created_at: time,
          updated_at: time
        }
      end
    end
  end
end
