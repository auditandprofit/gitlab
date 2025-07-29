# frozen_string_literal: true

module Ci
  class CompareSecurityReportsService < ::Ci::CompareReportsBaseService
    SECURITY_MR_WIDGET_POLLING_CACHE_TTL = 2.hours.in_seconds

    def self.transition_cache_key(pipeline_id: nil)
      return unless pipeline_id.present?

      "security_mr_widget::report_parsing_check::#{pipeline_id}:transitioning"
    end

    def self.ready_cache_key(pipeline_id: nil, report_type: nil)
      return unless pipeline_id.present?

      "security_mr_widget::report_parsing_check::#{report_type}::#{pipeline_id}"
    end

    def self.set_security_mr_widget_to_polling(pipeline_id: nil)
      return unless pipeline_id.present?

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(
          transition_cache_key(pipeline_id:),
          pipeline_id,
          ex: SECURITY_MR_WIDGET_POLLING_CACHE_TTL
        )
      end
    end

    def self.set_security_report_type_to_ready(pipeline_id: nil, report_type: nil)
      return unless pipeline_id.present? && report_type.present?

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(
          ready_cache_key(pipeline_id:, report_type:),
          pipeline_id,
          ex: SECURITY_MR_WIDGET_POLLING_CACHE_TTL
        )
      end
    end

    def self.set_security_mr_widget_to_ready(pipeline_id: nil)
      return unless pipeline_id.present?

      Gitlab::Redis::SharedState.with { |redis| redis.del(transition_cache_key(pipeline_id:)) }
    end

    def build_comparer(base_report, head_report)
      comparer_class.new(project, base_report, head_report)
    end

    def comparer_class
      Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer
    end

    def serializer_class
      Vulnerabilities::FindingDiffSerializer
    end

    def get_report(pipeline)
      # This is to delay polling in Projects::MergeRequestsController
      # until `Security::StoreFindingsService` is complete
      return :parsing unless ready_to_send_to_finder?(pipeline)

      findings = Security::FindingsFinder.new(
        pipeline,
        params: {
          report_type: [params[:report_type]],
          scope: 'all',
          limit: Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer::MAX_FINDINGS_COUNT
        }
      ).execute.with_api_scopes
      Gitlab::Ci::Reports::Security::AggregatedFinding.new(pipeline, findings)
    end

    private

    def ready_to_send_to_finder?(pipeline)
      return true if pipeline.nil? || report_type_ingested?(pipeline, params[:report_type])
      return false if ingesting_security_scans_for?(pipeline)

      !pipeline.security_scans.by_build_ids(
        pipeline.builds
          .with_reports_of_type(params[:report_type])
          .pluck_primary_key
      ).not_in_terminal_state.any?
    end

    def report_type_ingested?(pipeline, report_type)
      # rubocop:disable CodeReuse/ActiveRecord -- false positive
      Gitlab::Redis::SharedState.with do |redis|
        redis.exists?(
          self.class.ready_cache_key(pipeline_id: pipeline.id, report_type: report_type)
        )
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end

    def ingesting_security_scans_for?(pipeline)
      # rubocop:disable CodeReuse/ActiveRecord -- false positive
      Gitlab::Redis::SharedState.with do |redis|
        redis.exists?(self.class.transition_cache_key(pipeline_id: pipeline.id))
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end
