# frozen_string_literal: true

module WorkItems
  module Lifecycles
    class BaseService < ::BaseContainerService
      def initialize(...)
        super

        @statuses_to_create = []
        @statuses_to_update = []
        @statuses_to_remove = []
      end

      private

      def apply_status_changes
        return unless params[:statuses].present?

        @processed_statuses = process_statuses(params[:statuses])
        @statuses_to_remove = calculate_statuses_to_remove
      end

      def process_statuses(statuses)
        return [] unless statuses.present?

        statuses.map { |status_params| process_single_status(status_params) }
      end

      def process_single_status(status_params)
        if status_params[:id].present?
          handle_status_with_id(status_params)
        else
          handle_status_without_id(status_params)
        end
      end

      def handle_status_with_id(status_params)
        status = find_status_by_id(status_params[:id])

        case status
        when ::WorkItems::Statuses::SystemDefined::Status
          convert_system_to_custom_status!(status, status_params)
        when ::WorkItems::Statuses::Custom::Status
          ensure_status_belongs_to_namespace!(status)
          update_custom_status!(status, status_params)
          status
        end
      end

      def handle_status_without_id(status_params)
        existing_status = find_custom_status_by_name(status_params[:name])

        if existing_status
          update_custom_status!(existing_status, status_params)
          existing_status
        else
          create_custom_status!(prepare_custom_status_params(status_params)).tap do |status|
            @statuses_to_create << status
          end
        end
      end

      def convert_system_to_custom_status!(system_defined_status, status_params)
        prepared_params = prepare_custom_status_params(status_params, system_defined_status, system_defined_status.id)
        create_custom_status!(prepared_params).tap do |status|
          @statuses_to_update << status if converted_with_changes?(system_defined_status, status)
        end
      end

      def converted_with_changes?(system_defined_status, status)
        system_defined_status.name != status.name ||
          system_defined_status.color != status.color ||
          status.description.present?
      end

      def create_custom_status!(prepared_params)
        ::WorkItems::Statuses::Custom::Status.create!(prepared_params)
      end

      def update_custom_status!(status, status_params)
        update_attributes = status_params.to_h.slice(:name, :description, :color)

        status.assign_attributes(update_attributes)

        return unless status.changed?

        @statuses_to_update << status

        status.updated_by = current_user
        status.save!
      end

      def prepare_custom_status_params(status_params, system_defined_status = nil, converted_from_id = nil)
        {
          namespace: group,
          name: status_params[:name] || system_defined_status&.name,
          color: status_params[:color] || system_defined_status&.color,
          description: status_params[:description] || system_defined_status&.description,
          category: status_params[:category] || system_defined_status&.category,
          converted_from_system_defined_status_identifier: converted_from_id,
          created_by: current_user
        }
      end

      def find_status_by_id(global_id)
        global_id.model_class.find(global_id.model_id.to_i)
      end

      def find_custom_status_by_name(name)
        ::WorkItems::Statuses::Custom::Status.find_by_namespace_and_name(group.id, name)
      end

      def calculate_statuses_to_remove
        original_statuses = lifecycle.statuses.to_a

        if custom_lifecycle?
          original_statuses - @processed_statuses
        elsif system_defined_lifecycle?
          converted_ids = @processed_statuses.filter_map(&:converted_from_system_defined_status_identifier)
          original_statuses.reject { |status| converted_ids.include?(status.id) }
        end
      end

      def ensure_status_belongs_to_namespace!(status)
        return if status.namespace_id == lifecycle.namespace_id

        raise StandardError, "Status '#{status.name}' doesn't belong to this namespace."
      end

      def validate_status_removal_constraints
        return unless @statuses_to_remove&.any?

        validate_default_status_constraints
        validate_status_usage
      end

      def handle_deferred_status_removal
        return unless @statuses_to_remove&.any?

        status_ids = @statuses_to_remove.map(&:id)
        ::WorkItems::Statuses::Custom::Status.id_in(status_ids).delete_all
      end

      # We need to remove associated system-defined board lists because these cannot have a
      # foreign key constraint to cascade the deletion
      def remove_system_defined_board_lists
        return unless @statuses_to_remove&.any?

        system_defined_identifiers = @statuses_to_remove.filter_map do |status|
          if status.is_a?(WorkItems::Statuses::SystemDefined::Status)
            status.id
          else
            status.converted_from_system_defined_status_identifier
          end
        end

        return if system_defined_identifiers.blank?

        # rubocop: disable CodeReuse/ActiveRecord -- these queries will only be used here
        Namespaces::ProjectNamespace.where('traversal_ids[1] = ?', group.id).each_batch do |project_namespaces|
          project_ids = Project.where(project_namespace_id: project_namespaces.select(:id))

          ::List.where(
            project_id: project_ids,
            system_defined_status_identifier: system_defined_identifiers
          ).delete_all
        end

        Group.where('traversal_ids[1] = ?', group.id).each_batch do |groups|
          ::List.where(
            group_id: groups,
            system_defined_status_identifier: system_defined_identifiers
          ).delete_all
        end
        # rubocop: enable CodeReuse/ActiveRecord
      end

      def validate_status_usage
        @statuses_to_remove.each do |status|
          in_use = case status
                   when ::WorkItems::Statuses::SystemDefined::Status
                     status.in_use_in_namespace?(group)
                   when ::WorkItems::Statuses::Custom::Status
                     status.in_use?
                   end

          raise StandardError, "Cannot delete status '#{status.name}' because it is in use" if in_use
        end
      end

      def validate_default_status_constraints
        status_ids = @statuses_to_remove.map(&:id)

        default_status_ids = lifecycle.default_statuses.map(&:id)
        conflicting_ids = status_ids & default_status_ids

        return unless conflicting_ids.any?

        conflicting_status = @statuses_to_remove.find { |status| conflicting_ids.include?(status.id) }
        raise StandardError,
          "Cannot delete status '#{conflicting_status.name}' because it is marked as a default status"
      end

      def update_lifecycle_status_positions!
        lifecycle.reset

        # Delete directly without triggering lifecycle callbacks
        WorkItems::Statuses::Custom::LifecycleStatus.where(lifecycle_id: lifecycle.id).delete_all # rubocop: disable CodeReuse/ActiveRecord -- reason above

        lifecycle_status_data = @processed_statuses.map.with_index do |status, index|
          {
            lifecycle_id: lifecycle.id,
            status_id: status.id,
            namespace_id: lifecycle.namespace_id,
            position: index
          }
        end

        ::WorkItems::Statuses::Custom::LifecycleStatus.insert_all(lifecycle_status_data) if lifecycle_status_data.any?
      end

      def default_statuses_for_lifecycle(processed_statuses, attributes)
        default_status_mappings = {
          default_open_status: :default_open_status_index,
          default_closed_status: :default_closed_status_index,
          default_duplicate_status: :default_duplicate_status_index
        }

        default_status_mappings.each_with_object({}) do |(status_field, index_field), default_attributes|
          index = attributes[index_field]
          next unless index.present? && index < processed_statuses.length

          status = processed_statuses[index]
          default_attributes[status_field] = status if status
        end
      end

      def feature_available?
        group.try(:work_item_status_feature_available?)
      end

      def authorized?
        can?(current_user, :admin_work_item_lifecycle, group)
      end

      def system_defined_lifecycle?
        lifecycle.is_a?(::WorkItems::Statuses::SystemDefined::Lifecycle)
      end

      def custom_lifecycle?
        lifecycle.is_a?(::WorkItems::Statuses::Custom::Lifecycle)
      end
    end
  end
end
