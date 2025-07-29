# frozen_string_literal: true

module Admin
  class TargetedMessagesController < Admin::ApplicationController
    feature_category :acquisition

    before_action :verify_targeted_messages_enabled!
    before_action :find_targeted_message, only: [:edit, :update]

    def index
      @targeted_messages = Notifications::TargetedMessage.all
    end

    def new
      @targeted_message = Notifications::TargetedMessage.new
    end

    def create
      result = Notifications::TargetedMessages::CreateService.new(targeted_message_params).execute

      if result.success?
        redirect_to admin_targeted_messages_path,
          notice: s_('TargetedMessages|Targeted message was successfully created.')
      elsif result.reason == Notifications::TargetedMessages::CreateService::FOUND_INVALID_NAMESPACES
        @targeted_message = result.payload
        flash[:alert] = result.message
        render :edit
      else
        @targeted_message = result.payload
        render :new
      end
    end

    def edit; end

    def update
      result = Notifications::TargetedMessages::UpdateService.new(@targeted_message, targeted_message_params).execute

      if result.success?
        redirect_to admin_targeted_messages_path,
          notice: s_('TargetedMessages|Targeted message was successfully updated.')
      elsif result.reason == Notifications::TargetedMessages::UpdateService::FOUND_INVALID_NAMESPACES
        @targeted_message = result.payload
        flash[:alert] = result.message
        render :edit
      else
        @targeted_message = result.payload
        render :edit
      end
    end

    private

    def find_targeted_message
      @targeted_message = Notifications::TargetedMessage.find(params.permit(:id)[:id])
    end

    def verify_targeted_messages_enabled!
      render_404 unless Feature.enabled?(:targeted_messages_admin_ui, :instance) &&
        ::Gitlab::Saas.feature_available?(:targeted_messages)
    end

    def targeted_message_params
      params.require(:targeted_message).permit(:target_type, :namespace_ids_csv)
    end
  end
end
