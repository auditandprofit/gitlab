# frozen_string_literal: true
class Groups::Security::DashboardController < Groups::ApplicationController
  include GovernUsageGroupTracking

  layout 'group'

  feature_category :vulnerability_management
  urgency :low
  track_govern_activity 'security_dashboard', :show, conditions: :dashboard_available?
  track_internal_event :show, name: 'visit_security_dashboard', category: name,
    conditions: -> { dashboard_available? }

  before_action only: :show do
    push_frontend_feature_flag(:group_security_dashboard_new, group)
    push_frontend_feature_flag(:vulnerabilities_pdf_export, group)
  end

  def show
    render :unavailable unless dashboard_available?
  end

  private

  def dashboard_available?
    can?(current_user, :read_group_security_dashboard, group)
  end
end
