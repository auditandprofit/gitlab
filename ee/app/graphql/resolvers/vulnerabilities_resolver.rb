# frozen_string_literal: true

module Resolvers
  class VulnerabilitiesResolver < VulnerabilitiesBaseResolver
    include Gitlab::Utils::StrongMemoize
    include LooksAhead
    include Gitlab::InternalEventsTracking

    type Types::VulnerabilityType, null: true

    argument :project_id, [GraphQL::Types::ID],
      required: false,
      description: 'Filter vulnerabilities by project.'

    argument :report_type, [Types::VulnerabilityReportTypeEnum],
      required: false,
      description: 'Filter vulnerabilities by report type.'

    argument :severity, [Types::VulnerabilitySeverityEnum],
      required: false,
      description: 'Filter vulnerabilities by severity.'

    argument :state, [Types::VulnerabilityStateEnum],
      required: false,
      description: 'Filter vulnerabilities by state.'

    argument :owasp_top_ten, [Types::VulnerabilityOwaspTop10Enum],
      required: false,
      as: :owasp_top_10,
      description: 'Filter vulnerabilities by OWASP Top 10 2017 category. Wildcard value `NONE` is also supported ' \
                   'but it cannot be combined with other OWASP top 10 values.'

    argument :owasp_top_ten_2021, [::Types::Vulnerabilities::Owasp2021Top10Enum],
      required: false,
      as: :owasp_top_10_2021,
      experiment: { milestone: '18.1' },
      description: 'Filter vulnerabilities by OWASP Top 10 2021 category. Wildcard value `NONE` is also supported ' \
                   'but it cannot be combined with other OWASP top 10 2021 values. ' \
                   'To use this argument, you must have Elasticsearch configured and the ' \
                   '`advanced_vulnerability_management` feature flag enabled. ' \
                   'Not supported on Instance Security Dashboard queries.'

    argument :identifier_name, GraphQL::Types::String,
      required: false,
      description: 'Filter vulnerabilities by identifier name. ' \
                   'Ignored when applied on instance security dashboard queries.'

    argument :scanner, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerabilities by VulnerabilityScanner.externalId.'

    argument :scanner_id, [::Types::GlobalIDType[::Vulnerabilities::Scanner]],
      required: false,
      description: 'Filter vulnerabilities by scanner ID.'

    argument :sort, Types::VulnerabilitySortEnum,
      required: false,
      default_value: 'severity_desc',
      description: 'List vulnerabilities by sort order.'

    argument :has_resolution, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have been resolved on default branch.'

    argument :has_ai_resolution, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which can likely be resolved by GitLab Duo Vulnerability Resolution.'

    argument :has_issues, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have linked issues.'

    argument :has_merge_request, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have linked merge requests.'

    argument :image, [GraphQL::Types::String],
      required: false,
      description: "Filter vulnerabilities by location image. When this filter is present, "\
                   "the response only matches entries for a `reportType` "\
                   "that includes #{::Vulnerabilities::Finding::REPORT_TYPES_WITH_LOCATION_IMAGE.map { |type| "`#{type}`" }.join(', ')}."

    argument :cluster_id, [::Types::GlobalIDType[::Clusters::Cluster]],
      prepare: ->(ids, _) { ids.map(&:model_id) },
      required: false,
      description: "Filter vulnerabilities by `cluster_id`. Vulnerabilities with a `reportType` "\
                   "of `cluster_image_scanning` are only included with this filter."

    argument :cluster_agent_id, [::Types::GlobalIDType[::Clusters::Agent]],
      prepare: ->(ids, _) { ids.map(&:model_id) },
      required: false,
      description: "Filter vulnerabilities by `cluster_agent_id`. Vulnerabilities with a `reportType` "\
                   "of `cluster_image_scanning` are only included with this filter."

    argument :dismissal_reason, [Types::Vulnerabilities::DismissalReasonEnum],
      required: false,
      description: "Filter by dismissal reason. Only dismissed Vulnerabilities will be included with the filter."

    argument :has_remediations, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have remediations.'

    argument :reachability, ::Types::Sbom::ReachabilityEnum,
      required: false,
      experiment: { milestone: '18.2' },
      description: 'Filter vulnerabilities by reachability.'

    def resolve_with_lookahead(**args)
      return Vulnerability.none unless vulnerable&.feature_available?(:security_dashboard)

      validate_filters(args)
      set_data_source(args)
      track_event

      args[:scanner_id] = resolve_gids(args[:scanner_id], ::Vulnerabilities::Scanner) if args[:scanner_id]

      disabled_filters = context.response_extensions["disabled_filters"] ||= []
      disabled_filters << :identifier_name unless search_by_identifier_allowed_on_db?(vulnerable: vulnerable)

      fetch_vulnerabilities(args)
    end

    def unconditional_includes
      if using_elasticsearch # With ES we directly return Vulnerability records
        return [{ project: [:namespace, :group, :route] }, { findings: [:scanner, :identifiers] }, :vulnerability_read]
      end

      # project: [:route] is added in the as_vulnerabilities method.
      [{ vulnerability: [{ project: [:namespace, :group] }, { findings: [:scanner, :identifiers] }, :vulnerability_read] }]
    end

    def preloads
      base_associations = {
        has_remediations: { findings: :remediations },
        merge_request: :merge_requests,
        state_comment: :state_transitions,
        state_transitions: :state_transitions,
        false_positive: { findings: :vulnerability_flags },
        representation_information: :representation_information,
        location: { findings: :latest_finding_pipeline },
        links: { findings: :finding_links },
        external_issue_links: :external_issue_links,
        primary_identifier: { findings: :primary_identifier },
        initial_detected_pipeline: { findings: :initial_finding_pipeline },
        latest_detected_pipeline: { findings: :latest_finding_pipeline }
      }

      return base_associations if using_elasticsearch # With ES we directly return Vulnerability records

      wrap_with_vulnerability(base_associations)
    end

    private

    attr_reader :using_elasticsearch

    def set_data_source(args)
      @using_elasticsearch = use_elasticsearch?(args)
    end

    def fetch_vulnerabilities(args)
      if using_elasticsearch
        vulnerabilities_from_es(args)
      else
        finder_params = args.merge(before_severity: before_severity, after_severity: after_severity)

        vulnerabilities(finder_params)
      end
    end

    def vulnerabilities(finder_params)
      apply_lookahead(::Security::VulnerabilityReadsFinder.new(vulnerable, finder_params).execute.as_vulnerabilities)
    end

    def vulnerabilities_from_es(finder_params)
      apply_lookahead(::Security::VulnerabilityElasticSearchFinder.new(vulnerable, finder_params).execute)
    end

    def wrap_with_vulnerability(associations)
      associations.transform_values do |association|
        { vulnerability: association }
      end
    end

    def vulnerable_to_actor
      case vulnerable
      when ::InstanceSecurityDashboard
        current_user
      when Project
        vulnerable.group
      else
        vulnerable
      end
    end

    def after_severity
      severity_from_cursor(:after)
    end

    def before_severity
      severity_from_cursor(:before)
    end

    def severity_from_cursor(cursor)
      cursor_value = current_arguments && current_arguments[cursor]

      return unless cursor_value

      decoded_cursor = Base64.urlsafe_decode64(cursor_value)

      Gitlab::Json.parse(decoded_cursor)['severity']
    rescue ArgumentError, JSON::ParserError
    end

    def current_arguments
      context[:current_arguments]
    end

    def track_event
      track_internal_event(
        "called_vulnerability_api",
        user: current_user,
        project: vulnerable.is_a?(::Project) ? vulnerable : nil,
        namespace: vulnerable.is_a?(::Group) ? vulnerable : nil,
        additional_properties: {
          label: 'graphql',
          value: using_elasticsearch ? 1 : 0
        }
      )
    end
  end
end
