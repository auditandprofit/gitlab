# frozen_string_literal: true

module WorkItems
  class TypeCustomLifecycle < ApplicationRecord
    self.table_name = 'work_item_type_custom_lifecycles'

    belongs_to :namespace
    belongs_to :work_item_type, class_name: 'WorkItems::Type'
    belongs_to :lifecycle, class_name: 'WorkItems::Statuses::Custom::Lifecycle'

    before_validation :copy_namespace_from_lifecycle

    validates :namespace, :work_item_type, :lifecycle, presence: true
    validates :lifecycle, uniqueness: { scope: [:namespace_id, :work_item_type_id] }
    validate :validate_status_widget_availability

    private

    def copy_namespace_from_lifecycle
      self.namespace ||= lifecycle&.namespace
    end

    # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- small number of widgets
    def validate_status_widget_availability
      return if work_item_type.nil?
      return if namespace.nil?
      return if work_item_type.widgets(namespace).pluck(:widget_type).include?('status')

      errors.add(:work_item_type, 'does not support status widget')
    end
    # rubocop: enable Database/AvoidUsingPluckWithoutLimit
  end
end
