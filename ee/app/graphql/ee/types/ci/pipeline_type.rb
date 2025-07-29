# frozen_string_literal: true

module EE
  module Types
    module Ci
      module PipelineType
        extend ActiveSupport::Concern

        prepended do
          field :compute_minutes,
            GraphQL::Types::Float,
            null: true,
            method: :total_ci_minutes_consumed,
            description: "Total minutes consumed by the pipeline."

          field :security_report_summary,
            ::Types::SecurityReportSummaryType,
            null: true,
            extras: [:lookahead],
            description: 'Vulnerability and scanned resource counts for each security scanner of the pipeline.',
            resolver: ::Resolvers::SecurityReportSummaryResolver

          # rubocop:disable Layout/LineLength -- otherwise description is creating unnecessary spaces.
          field :security_report_findings,
            ::Types::PipelineSecurityReportFindingType.connection_type,
            null: true,
            description: 'Vulnerability findings reported on the pipeline. By default all the states except dismissed are included in the response.',
            # Although we're not paginating an Array here we're using this
            # connection extension because it leaves the pagination
            # arguments available for the resolver.  Otherwise they are
            # removed by the framework.
            connection_extension: ::Gitlab::Graphql::Extensions::ExternallyPaginatedArrayExtension,
            resolver: ::Resolvers::PipelineSecurityReportFindingsResolver
          # rubocop:enable Layout/LineLength

          field :security_report_finding,
            ::Types::PipelineSecurityReportFindingType,
            null: true,
            description: 'Vulnerability finding reported on the pipeline.',
            resolver: ::Resolvers::SecurityReport::FindingResolver

          field :code_quality_reports,
            ::Types::Ci::CodeQualityDegradationType.connection_type,
            null: true,
            description: 'Code Quality degradations reported on the pipeline.'

          field :code_quality_report_summary,
            ::Types::Ci::CodeQualityReportSummaryType,
            null: true,
            description: 'Code Quality report summary for a pipeline.'

          field :dast_profile,
            ::Types::Dast::ProfileType,
            null: true,
            description: 'DAST profile associated with the pipeline.'

          field :troubleshoot_job_with_ai, GraphQL::Types::Boolean, null: false,
            description: "If the user can troubleshoot jobs of a pipeline."

          def troubleshoot_job_with_ai
            return false unless current_user

            current_user.can?(:troubleshoot_job_with_ai, pipeline)
          end

          def code_quality_reports
            pipeline.codequality_reports.sort_degradations!.values.presence
          end

          def code_quality_report_summary
            pipeline.codequality_reports.code_quality_report_summary
          end

          def dast_profile
            pipeline.dast_profile
          end
        end
      end
    end
  end
end
