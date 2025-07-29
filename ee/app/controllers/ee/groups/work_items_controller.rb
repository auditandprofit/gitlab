# frozen_string_literal: true

module EE
  module Groups
    module WorkItemsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      prepended do
        before_action :authorize_read_work_item!, only: [:description_diff, :delete_description_version]
        before_action :set_application_context!, only: [:show]

        include DescriptionDiffActions
      end

      def show
        # We want to keep the experience for users to use the /epics/:iid URL even when they use /work_items/:iid
        return redirect_to group_epic_path(group, issuable.iid) if epic_work_item?

        super
      end

      private

      def issuable
        ::WorkItem.find_by_namespace_and_iid!(group, params[:iid])
      end
      strong_memoize_attr :issuable

      def epic_work_item?
        issuable.work_item_type == ::WorkItems::Type.default_by_type(:epic)
      end

      def authorize_read_work_item!
        access_denied! unless can?(current_user, :read_work_item, issuable)
      end

      def set_application_context!
        ::Gitlab::ApplicationContext.push(ai_resource: issuable.try(:to_global_id))
      end
    end
  end
end
