# frozen_string_literal: true

module WorkItems
  module HasStatus
    extend ActiveSupport::Concern

    included do
      has_one :current_status, class_name: 'WorkItems::Statuses::CurrentStatus',
        foreign_key: 'work_item_id', inverse_of: :work_item

      scope :with_status, ->(status) {
        relation = left_joins(:current_status)

        if status.is_a?(::WorkItems::Statuses::SystemDefined::Status)
          relation = with_system_defined_status(status)
        else
          relation = relation
            .where.not(work_item_current_statuses: { custom_status_id: nil })
            .where(work_item_current_statuses: { custom_status_id: status.id })

          if status.converted_from_system_defined_status_identifier.present?
            system_defined_status = WorkItems::Statuses::SystemDefined::Status.find(
              status.converted_from_system_defined_status_identifier
            )

            relation = relation.or(with_system_defined_status(system_defined_status))
          end
        end

        relation
      }

      scope :with_system_defined_status, ->(status) {
        next none unless status.is_a?(::WorkItems::Statuses::SystemDefined::Status)

        relation = left_joins(:current_status)
                    .where.not(work_item_current_statuses: { system_defined_status_id: nil })
                    .where(work_item_current_statuses: { system_defined_status_id: status.id })

        lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first

        with_default_status = case status.id
                              when lifecycle.default_open_status_id
                                opened
                              when lifecycle.default_duplicate_status_id
                                closed.where.not(duplicated_to_id: nil)
                              when lifecycle.default_closed_status_id
                                closed.where(duplicated_to_id: nil)
                              end

        next relation if with_default_status.nil?

        relation.or(
          with_default_status.without_current_status.with_issue_type(lifecycle.work_item_base_types)
        )
      }

      scope :without_current_status, -> { left_joins(:current_status).where(work_item_current_statuses: { id: nil }) }

      scope :not_in_statuses, ->(statuses) {
        return all if statuses.blank?

        items_to_exclude = statuses.reduce(unscoped.none) do |relation, status|
          relation.or(with_status(status))
        end

        merge(items_to_exclude.invert_where)
      }

      def status_with_fallback
        current_status_with_fallback&.status
      end

      def current_status_with_fallback
        return current_status if current_status.present?

        lifecycle = work_item_type.system_defined_lifecycle
        return unless lifecycle

        build_current_status(system_defined_status: lifecycle.default_status_for_work_item(self))
      end
    end
  end
end
