# frozen_string_literal: true

module WorkItems
  module Statuses
    module Custom
      class Status < ApplicationRecord
        self.table_name = 'work_item_custom_statuses'

        include WorkItems::Statuses::Status
        include ::WorkItems::ConfigurableStatus

        MAX_STATUSES_PER_NAMESPACE = 70

        enum :category, CATEGORIES

        belongs_to :namespace
        belongs_to :created_by, class_name: 'User', optional: true
        belongs_to :updated_by, class_name: 'User', optional: true

        has_many :lifecycle_statuses,
          class_name: 'WorkItems::Statuses::Custom::LifecycleStatus',
          inverse_of: :status

        has_many :lifecycles,
          through: :lifecycle_statuses,
          class_name: 'WorkItems::Statuses::Custom::Lifecycle'

        scope :in_namespace, ->(namespace) { where(namespace: namespace) }
        scope :ordered_for_lifecycle, ->(lifecycle_id) {
          joins(:lifecycle_statuses)
            .where(work_item_custom_lifecycle_statuses: { lifecycle_id: lifecycle_id })
            .order('work_item_custom_statuses.category ASC,
                    work_item_custom_lifecycle_statuses.position ASC,
                    work_item_custom_statuses.id ASC')
        }

        scope :converted_from_system_defined, -> { where.not(converted_from_system_defined_status_identifier: nil) }

        validates :namespace, :category, presence: true
        validates :name, presence: true, length: { maximum: 32 }
        # Note that currently all statuses are created at root group level, if we would ever want to allow statuses
        # to be created at subgroup level, but unique across groups hierarchy, then this validation would need
        # to be adjusted to compute the uniqueness across hierarchy.
        validates :name, custom_uniqueness: { unique_sql: 'TRIM(BOTH FROM lower(?))', scope: :namespace_id }
        validates :color, presence: true, length: { maximum: 7 }, color: true
        validates :description, length: { maximum: 128 }, allow_blank: true
        # Update doesn't change the overall status per namespace count
        # because you won't be able to change the namespace through the API.
        validate :validate_statuses_per_namespace_limit, on: :create

        def self.find_by_namespace_and_name(namespace, name)
          in_namespace(namespace).find_by('TRIM(BOTH FROM LOWER(name)) = TRIM(BOTH FROM LOWER(?))', name)
        end

        def position
          # Temporarily default to 0 as it is not meaningful without lifecycle context
          0
        end

        def in_use?
          return true if direct_usage_exists?
          return false unless has_system_defined_mapping?

          system_defined_usage_exists?
        end

        private

        def validate_statuses_per_namespace_limit
          return unless namespace.present?
          return unless Status.where(namespace_id: namespace.id).count >= MAX_STATUSES_PER_NAMESPACE

          errors.add(:namespace,
            format(_('can only have a maximum of %{limit} statuses.'), limit: MAX_STATUSES_PER_NAMESPACE)
          )
        end

        def direct_usage_exists?
          ::WorkItems::Statuses::CurrentStatus.exists?(custom_status: self)
        end

        def has_system_defined_mapping?
          converted_from_system_defined_status_identifier.present?
        end

        def system_defined_usage_exists?
          system_defined_status = ::WorkItems::Statuses::SystemDefined::Status.find(
            converted_from_system_defined_status_identifier
          )

          system_defined_status.in_use_in_namespace?(namespace)
        end
      end
    end
  end
end
