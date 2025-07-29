# frozen_string_literal: true

module DependenciesHelper
  include API::Helpers::RelatedResourcesHelpers

  def project_dependencies_data(project)
    pipeline = project.latest_ingested_sbom_pipeline

    shared_dependencies_data.merge({
      has_dependencies: project.has_dependencies?.to_s,
      endpoint: project_dependencies_path(project, format: :json),
      licenses_endpoint: licenses_project_dependencies_path(project),
      export_endpoint: expose_path(api_v4_projects_dependency_list_exports_path(id: project.id)),
      vulnerabilities_endpoint: expose_path(api_v4_occurrences_vulnerabilities_path),
      sbom_reports_errors: sbom_report_ingestion_errors(pipeline).to_json,
      latest_successful_scan_path: (project_pipeline_path(project, pipeline) if pipeline),
      scan_finished_at: pipeline&.finished_at,
      project_full_path: project.full_path
    })
  end

  def group_dependencies_data(group)
    shared_dependencies_data.merge({
      has_dependencies: group.has_dependencies?.to_s,
      endpoint: group_dependencies_path(group, format: :json),
      licenses_endpoint: licenses_group_dependencies_path(group),
      locations_endpoint: locations_group_dependencies_path(group),
      export_endpoint: expose_path(api_v4_groups_dependency_list_exports_path(id: group.id)),
      vulnerabilities_endpoint: expose_path(api_v4_occurrences_vulnerabilities_path),
      group_full_path: group.full_path
    })
  end

  def explore_dependencies_data(organization, page_info)
    shared_dependencies_data.merge({
      has_dependencies: Sbom::Occurrence.unarchived.exists?.to_s,
      page_info: page_info,
      endpoint: explore_dependencies_path(format: :json),
      licenses_endpoint: nil,
      locations_endpoint: nil,
      export_endpoint: expose_path(api_v4_organizations_dependency_list_exports_path(id: organization.id)),
      vulnerabilities_endpoint: nil
    })
  end

  def dependencies_export_download_url(export)
    expose_url(api_v4_dependency_list_exports_download_path(export_id: export.id))
  end

  def dependencies_exportable_link(export)
    exportable = export.exportable

    link_text = case exportable
                when ::Project, ::Group
                  exportable.full_name
                when ::Organizations::Organization
                  exportable.name
                when ::Ci::Pipeline
                  "##{exportable.id}"
                end

    url = Gitlab::UrlBuilder.build(exportable)

    link = link_to(link_text, url)

    exportable_type = exportable.class.name.demodulize.underscore

    # rubocop:disable Rails/OutputSafety -- url helper output is safe
    "#{exportable_type} #{link}".html_safe
    # rubocop:enable Rails/OutputSafety
  end

  private

  def shared_dependencies_data
    {
      documentation_path: help_page_path('user/application_security/dependency_list/_index.md'),
      empty_state_svg_path: image_path('illustrations/empty-state/empty-radar-md.svg')
    }
  end

  def sbom_report_ingestion_errors(pipeline)
    pipeline&.sbom_report_ingestion_errors || []
  end
end
