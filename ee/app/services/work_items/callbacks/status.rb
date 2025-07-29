# frozen_string_literal: true

module WorkItems
  module Callbacks
    class Status < Base
      include Gitlab::Utils::StrongMemoize

      ALLOWED_PARAMS = [:status].freeze

      def self.execute_without_params?
        true
      end

      def after_create
        return unless root_ancestor&.try(:work_item_status_feature_available?)

        if status_from_params
          update_current_status(status_from_params)
        else
          # Ensure any supported item has a valid status upon creation
          ::WorkItems::Widgets::Statuses::UpdateService.new(
            work_item, current_user, :default
          ).execute
        end
      end

      def after_update
        return if excluded_in_new_type?
        return unless root_ancestor&.try(:work_item_status_feature_available?)

        update_current_status(status_from_params)
      end

      private

      def status_from_params
        return unless params[:status].present? && lifecycle&.has_status_id?(params[:status].id)
        return unless has_permission?(:"set_#{issuable.to_ability_name}_metadata")

        params[:status]
      end
      strong_memoize_attr :status_from_params

      def update_current_status(status)
        return unless status

        case status.state
        when :open
          if work_item.closed?
            Issues::ReopenService.new(container: work_item.namespace, current_user: current_user)
              .execute(work_item, status: status)
          else
            ::WorkItems::Widgets::Statuses::UpdateService.new(work_item, current_user, status).execute
          end
        when :closed
          if work_item.open?
            Issues::CloseService.new(container: work_item.namespace, current_user: current_user)
              .execute(work_item, status: status)
          else
            ::WorkItems::Widgets::Statuses::UpdateService.new(work_item, current_user, status).execute
          end
        end
      end

      def lifecycle
        work_item.work_item_type.status_lifecycle_for(root_ancestor)
      end
      strong_memoize_attr :lifecycle

      def root_ancestor
        work_item.resource_parent&.root_ancestor
      end
      strong_memoize_attr :root_ancestor
    end
  end
end
