# frozen_string_literal: true

module GitlabSubscriptions
  class GroupsController < ApplicationController
    include RoutableActions

    layout 'minimal'

    before_action :authenticate_user!

    before_action :find_group, except: %i[new create]
    before_action :authorize_admin_group!, except: %i[new create]

    feature_category :subscription_management
    urgency :low

    def new
      @plan_data = find_plan

      return not_found unless @plan_data

      @eligible_groups = GitlabSubscriptions::PurchaseEligibleNamespacesFinder.new(
        user: current_user,
        plan_id: @plan_data[:id]
      ).execute
    end

    def create
      name = group_params[:name]
      path = Namespace.clean_path(group_params[:path] || name)

      response = Groups::CreateService.new(
        current_user, name: name, path: path, organization_id: Current.organization.id
      ).execute

      if response.success?
        render json: { id: response[:group].id }, status: :created
      else
        render json: { errors: response[:group]&.errors }, status: :unprocessable_entity
      end
    end

    def edit
      render layout: 'checkout'
    end

    def update
      if Groups::UpdateService.new(@group, current_user, group_params).execute
        notice = if ::Gitlab::Utils.to_boolean(subscription_params[:new_user])
                   format(_('Welcome to GitLab, %{first_name}!'), first_name: current_user.first_name)
                 else
                   format(_('Subscription successfully applied to "%{group_name}"'), group_name: @group.name)
                 end

        redirect_to group_path(@group), notice: notice
      else
        @group.path = @group.path_before_last_save || @group.path_was
        render action: :edit, layout: 'checkout'
      end
    end

    private

    def find_group
      @group ||= find_routable!(Group, group_id_param[:id], request.fullpath)
    end

    def authorize_admin_group!
      access_denied! unless can?(current_user, :admin_group, @group)
    end

    def group_params
      params.require(:group).permit(:name, :path, :visibility_level)
    end

    def group_id_param
      params.permit(:id)
    end

    def subscription_params
      params.permit(:new_user, :plan_id)
    end

    def build_canonical_path(group)
      url_for(safe_params.merge(id: group.to_param))
    end

    def find_plan
      return unless subscription_params[:plan_id]

      all_plans = GitlabSubscriptions::FetchSubscriptionPlansService.new(plan: :free).execute

      all_plans.find { |plan| plan[:id] == subscription_params[:plan_id] }
    end
  end
end
