# frozen_string_literal: true

class Groups::EpicsController < Groups::ApplicationController
  include IssuableActions
  include IssuableCollections
  include ToggleAwardEmoji
  include ToggleSubscriptionAction
  include EpicsActions
  include DescriptionDiffActions

  before_action :check_epics_available!
  before_action :epic, except: [:index, :new, :bulk_update]
  before_action :authorize_update_issuable!, only: :update
  before_action :authorize_create_epic!, only: [:new]
  before_action :verify_group_bulk_edit_enabled!, only: [:bulk_update]
  before_action :set_summarize_notes_feature_flag, only: :show
  before_action :enforce_work_item_epics_feature_flags, only: [:new, :show]
  after_action :log_epic_show, only: :show

  before_action do
    push_frontend_feature_flag(:preserve_markdown, @group)
    push_frontend_feature_flag(:notifications_todos_buttons, current_user)

    push_force_frontend_feature_flag(:glql_load_on_click, !!@group&.glql_load_on_click_feature_flag_enabled?)
    push_force_frontend_feature_flag(:work_items_alpha, !!group.work_items_alpha_feature_flag_enabled?)
    push_frontend_feature_flag(:epics_list_drawer, @group)
    push_frontend_feature_flag(:work_item_status_feature_flag, @group&.root_ancestor)
    push_force_frontend_feature_flag(:work_items_bulk_edit, @group&.work_items_bulk_edit_feature_flag_enabled?)
  end

  before_action only: :show do
    push_frontend_ability(ability: :measure_comment_temperature, resource: epic, user: current_user)
  end

  feature_category :portfolio_management
  urgency :default, [:show, :new, :realtime_changes]
  urgency :low, [:discussions]
  def show
    respond_to do |format|
      format.html do
        render_as_work_item
      end
      format.json do
        render json: serializer.represent(epic)
      end
    end
  end

  def new
    page_title _('New epic')
    render 'groups/work_items/show'
  end

  def index
    render 'work_items_index'
  end

  private

  # rubocop: disable CodeReuse/ActiveRecord
  def epic
    @issuable = @epic ||= @group.epics.find_by(iid: params[:epic_id] || params[:id])

    return render_404 unless can?(current_user, :read_epic, @epic)

    @noteable = @epic
  end
  # rubocop: enable CodeReuse/ActiveRecord
  alias_method :issuable, :epic
  alias_method :awardable, :epic
  alias_method :subscribable_resource, :epic

  def subscribable_project
    nil
  end

  def render_as_work_item
    @work_item = epic.work_item

    render 'work_items_index'
  end

  def epic_params
    params.require(:epic).permit(*epic_params_attributes)
  end

  def epic_params_attributes
    [
      :color,
      :title,
      :description,
      :start_date_fixed,
      :start_date_is_fixed,
      :due_date_fixed,
      :due_date_is_fixed,
      :state_event,
      :confidential,
      { label_ids: [],
        update_task: [:index, :checked, :line_number, :line_source] }
    ]
  end

  def serializer
    EpicSerializer.new(current_user: current_user)
  end

  def discussion_serializer
    Epics::DiscussionSerializer.new(
      project: nil,
      noteable: issuable,
      current_user: current_user,
      note_entity: EpicNoteEntity
    )
  end

  def update_service
    ::WorkItems::LegacyEpics::UpdateService.new(group: @group, current_user: current_user,
      params: epic_params)
  end

  def sorting_field
    :epics_sort
  end

  def log_epic_show
    return unless current_user && @epic

    ::Gitlab::Search::RecentEpics.new(user: current_user).log_view(@epic)
  end

  def authorize_create_epic!
    render_404 unless can?(current_user, :create_epic, group)
  end

  def verify_group_bulk_edit_enabled!
    render_404 unless group.licensed_feature_available?(:group_bulk_edit)
  end

  def enforce_work_item_epics_feature_flags
    # We enforce the feature flag, in case that the frontend still relies on it.
    push_force_frontend_feature_flag(:work_item_epics, !!@group.licensed_feature_available?(:epics))
  end

  def set_summarize_notes_feature_flag
    push_force_frontend_feature_flag(:summarize_comments, can?(current_user, :summarize_comments, epic))
  end
end
