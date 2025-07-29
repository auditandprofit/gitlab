# frozen_string_literal: true

class Projects::AuditEventsController < Projects::ApplicationController
  include SecurityAndCompliancePermissions
  include Gitlab::Utils::StrongMemoize
  include LicenseHelper
  include AuditEvents::EnforcesValidDateParams
  include AuditEvents::AuditEventsParams
  include AuditEvents::Sortable
  include AuditEvents::DateRange
  include GovernUsageProjectTracking

  before_action :check_audit_events_available!

  track_govern_activity 'audit_events', :index

  feature_category :audit_events

  urgency :low

  def index
    @is_last_page = events.last_page?
    @events = AuditEventSerializer.new.represent(events)

    Gitlab::Tracking.event(self.class.name, 'search_audit_event', user: current_user, project: project, namespace: project.namespace)
  end

  def additional_properties_for_tracking
    return {} unless active_compliance_frameworks?

    { with_active_compliance_frameworks: 'true' }
  end

  private

  def active_compliance_frameworks?
    namespace = project.root_ancestor

    namespace.is_a?(::Group) && namespace.active_compliance_frameworks?
  end

  def check_audit_events_available!
    render_404 unless can?(current_user, :read_project_audit_events, project) &&
      (project.feature_available?(:audit_events) || show_promotions?(current_user))
  end

  def events
    strong_memoize(:events) do
      if ::Feature.enabled?(:read_audit_events_from_new_tables, project)
        events = ::AuditEvents::ProjectAuditEventFinder
                   .new(project: project, params: audit_params)
                   .execute
                   .page(pagination_params[:page])
                   .without_count
      else
        level = Gitlab::Audit::Levels::Project.new(project: project)
        events = AuditEventFinder
                   .new(level: level, params: audit_params)
                   .execute
                   .page(pagination_params[:page])
                   .without_count
      end

      Gitlab::Audit::Events::Preloader.preload!(events)
    end
  end

  def can_view_events_from_all_members?(user)
    can?(user, :admin_project, project) || user.auditor?
  end
end
