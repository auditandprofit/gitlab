# frozen_string_literal: true

module VulnerabilitiesHelper
  include ::API::Helpers::RelatedResourcesHelpers

  FINDING_FIELDS = %i[metadata identifiers name issue_feedback merge_request_feedback project scanner uuid details dismissal_feedback false_positive state_transitions issue_links merge_request_links].freeze

  def vulnerability_details_app_data(vulnerability, pipeline, project)
    {
      vulnerability: vulnerability_details_json(vulnerability, pipeline),
      can_view_false_positive: project.licensed_feature_available?(:sast_fp_reduction).to_s,
      commit_path_template: commit_path_template(project),
      project_full_path: project.full_path,
      default_branch: project.default_branch,
      customize_jira_issue_enabled: project.jira_integration&.customize_jira_issue_enabled.to_s
    }
  end

  def vulnerability_details_json(vulnerability, pipeline)
    vulnerability_details(vulnerability, pipeline).to_json
  end

  def vulnerability_details(vulnerability, pipeline)
    return unless vulnerability

    result = {
      timestamp: Time.now.to_i,
      new_issue_url: new_issue_url_for(vulnerability),
      create_jira_issue_url: create_jira_issue_url_for(vulnerability),
      related_jira_issues_path: project_integrations_jira_issues_path(vulnerability.project, state: 'all', vulnerability_ids: [vulnerability.id]),
      jira_integration_settings_path: edit_project_settings_integration_path(vulnerability.project, ::Integrations::Jira),
      create_mr_url: create_vulnerability_feedback_merge_request_path(vulnerability.finding.project),
      discussions_url: discussions_project_security_vulnerability_path(vulnerability.project, vulnerability),
      notes_url: project_security_vulnerability_notes_path(vulnerability.project, vulnerability),
      related_issues_help_path: help_page_path('user/application_security/vulnerabilities/_index.md', anchor: 'linking-a-vulnerability-to-gitlab-and-jira-issues'),
      pipeline: vulnerability_pipeline_data(pipeline),
      can_modify_related_issues: current_user.can?(:admin_vulnerability_issue_link, vulnerability),
      can_admin: current_user.can?(:admin_vulnerability, vulnerability.project),
      issue_tracking_help_path: help_page_path('user/project/issues/_index.md'),
      permissions_help_path: help_page_path('user/permissions.md', anchor: 'project-members-permissions'),
      dismissal_descriptions: dismissal_descriptions,
      representation_information: format_vulnerability_representation_information(vulnerability.representation_information),
      severity_override: severity_override_data(vulnerability),
      archival_information: archival_information(vulnerability)
    }

    result.merge(vulnerability_data(vulnerability), vulnerability_finding_data(vulnerability))
  end

  def archival_information(vulnerability)
    {
      about_to_be_archived: vulnerability.about_to_be_archived?,
      expected_to_be_archived_on: vulnerability.expected_to_be_archived_on
    }
  end

  def dismissal_descriptions
    Vulnerabilities::DismissalReasonEnum.translated_descriptions
  end

  def severity_override_data(vulnerability)
    severity_override = vulnerability.severity_overrides.last
    return unless severity_override

    {
      id: severity_override.id,
      original_severity: severity_override.original_severity,
      new_severity: severity_override.new_severity,
      author: {
        name: severity_override.author.name,
        web_url: user_path(severity_override.author)
      },
      created_at: severity_override.created_at
    }
  end

  def new_issue_url_for(vulnerability)
    return unless vulnerability.project.issues_enabled?

    new_project_issue_path(vulnerability.project, { vulnerability_id: vulnerability.id })
  end

  # This method can be called with an instance of the following models;
  # - Vulnerability
  # - Vulnerabilities::Finding
  # - Security::Finding
  #
  def create_jira_issue_url_for(vulnerability)
    return unless vulnerability.project.configured_to_create_issues_from_vulnerabilities?

    decorated_vulnerability = vulnerability.present
    summary = _('Investigate vulnerability: %{title}') % { title: decorated_vulnerability.title }
    description = ApplicationController.render(
      template: 'vulnerabilities/jira_issue_description',
      formats: :md,
      locals: { vulnerability: decorated_vulnerability }
    )

    vulnerability.project.jira_integration.new_issue_url_with_predefined_fields(summary, description)
  end

  def vulnerability_pipeline_data(pipeline)
    return unless pipeline

    {
      id: pipeline.id,
      created_at: pipeline.created_at.iso8601,
      url: pipeline_path(pipeline),
      source_branch: pipeline.ref
    }
  end

  def vulnerability_data(vulnerability)
    VulnerabilitySerializer.new.represent(vulnerability)
  end

  def format_vulnerability_representation_information(representation_information)
    return unless representation_information

    {
      resolved_in_commit_sha: representation_information.resolved_in_commit_sha,
      resolved_in_commit_sha_link: resolved_in_commit_sha_link(representation_information),
      created_at: representation_information.created_at
    }
  end

  def resolved_in_commit_sha_link(representation_information)
    return unless representation_information&.resolved_in_commit_sha

    commit_path_template(representation_information.project).gsub('$COMMIT_SHA', representation_information.resolved_in_commit_sha)
  end

  def vulnerability_finding_data(vulnerability)
    finding = vulnerability.finding

    data = Vulnerabilities::FindingSerializer.new(current_user: current_user).represent(finding, only: FINDING_FIELDS)
    data[:location].merge!('blob_path' => vulnerability.blob_path).compact!
    data[:description_html] = markdown(vulnerability.present.description)
    data[:solution_html] = markdown(vulnerability.present.solution)
    data[:ai_explanation_available] = finding.ai_explanation_available?
    data[:ai_resolution_available] = finding.ai_resolution_available?
    data[:belongs_to_public_project] = vulnerability.project.public?
    data[:cve_enrichment] = cve_enrichment(finding)
    data[:cvss] = cvss(finding)
    if Feature.enabled?(:validity_checks, finding.project) && finding.project.security_setting&.validity_checks_enabled
      data[:finding_token_status] = finding.finding_token_status
    end

    if Feature.enabled?(:validity_checks, finding.project)
      data[:validity_checks_enabled] = finding.project&.security_setting&.validity_checks_enabled || false
    end

    data
  end

  def cve_enrichment(finding)
    return unless finding.cve_enrichment

    {
      epss_score: finding.cve_enrichment.epss_score,
      is_known_exploit: finding.cve_enrichment.is_known_exploit
    }
  end

  def cvss(finding)
    return [] unless finding.advisory&.cvss_v3

    [{
      overall_score: finding.advisory.cvss_v3.overall_score,
      version: finding.advisory.cvss_v3.version
    }]
  end

  def vulnerability_scan_data?(vulnerability)
    vulnerability.scanner.present? || vulnerability.scan.present?
  end

  def vulnerabilities_export_download_url(export)
    expose_url(api_v4_security_vulnerability_exports_download_path(id: export.id))
  end

  def vulnerabilities_exportable_link(export)
    exportable = export.exportable

    link_text = exportable.full_name

    url = Gitlab::UrlBuilder.build(exportable)

    link = link_to(link_text, url)

    exportable_type = exportable.class.name.demodulize.underscore

    # rubocop:disable Rails/OutputSafety -- url helper output is safe
    "#{exportable_type} #{link}".html_safe
    # rubocop:enable Rails/OutputSafety
  end
end
