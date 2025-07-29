# frozen_string_literal: true

module Issuables
  class CustomField < ApplicationRecord
    include Gitlab::SQL::Pattern

    MAX_FIELDS = 100
    MAX_ACTIVE_FIELDS = 50
    MAX_ACTIVE_FIELDS_PER_TYPE = 10
    MAX_SELECT_OPTIONS = 50

    enum :field_type, { single_select: 0, multi_select: 1, number: 2, text: 3 }, prefix: true

    belongs_to :namespace
    belongs_to :created_by, class_name: 'User', optional: true
    belongs_to :updated_by, class_name: 'User', optional: true
    # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
    has_many :select_options, -> { order(:position, :id) }, dependent: :delete_all, autosave: true,
      # rubocop:enable Cop/ActiveRecordDependent -- legacy usage
      class_name: 'Issuables::CustomFieldSelectOption', inverse_of: :custom_field
    has_many :work_item_type_custom_fields, class_name: 'WorkItems::TypeCustomField'
    has_many :work_item_types, -> { order(:name) },
      class_name: 'WorkItems::Type', through: :work_item_type_custom_fields

    validates :namespace, :field_type, presence: true
    validates :name, presence: true, length: { maximum: 255 },
      uniqueness: { scope: [:namespace_id], case_sensitive: false }
    validates :select_options, length: {
      maximum: MAX_SELECT_OPTIONS,
      message: ->(*) { _('exceeds the limit of %{count}.') }
    }

    validate :namespace_is_root_group
    validate :number_of_fields_per_namespace
    validate :number_of_active_fields_per_namespace
    validate :number_of_active_fields_per_namespace_per_type
    validate :selectable_field_type_with_select_options

    scope :of_namespace, ->(namespace) { where(namespace_id: namespace) }
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
    scope :ordered_by_status_and_name, -> { order(Arel.sql('archived_at IS NULL').desc, name: :asc) }
    scope :of_field_type, ->(field_type) { where(field_type: field_type) }

    class << self
      def without_any_work_item_types
        where_not_exists(associated_work_item_type_relation)
      end

      def with_work_item_types(work_item_types)
        return without_any_work_item_types if work_item_types.empty?

        where_exists(associated_work_item_type_relation(work_item_type: work_item_types))
      end

      private

      def associated_work_item_type_relation(work_item_type: nil)
        work_item_type_custom_field_table = WorkItems::TypeCustomField.arel_table

        relation = WorkItems::TypeCustomField
          .where(work_item_type_custom_field_table[:namespace_id].eq(arel_table[:namespace_id]))
          .where(work_item_type_custom_field_table[:custom_field_id].eq(arel_table[:id]))

        relation = relation.where(work_item_type_id: work_item_type) if work_item_type

        relation
      end
    end

    def active?
      archived_at.nil?
    end

    def field_type_select?
      field_type_single_select? || field_type_multi_select?
    end

    # These associations have ordering scopes. We need to reset these when mutated
    # so that the cache is cleared and they are fetched again in the correct order.
    def reset_ordered_associations
      select_options.reset
      work_item_types.reset
    end

    private

    def namespace_is_root_group
      return if namespace.nil?
      return if namespace.group_namespace? && namespace.root?

      errors.add(:namespace, _('must be a root group.'))
    end

    def number_of_fields_per_namespace
      return if namespace.nil?
      return unless self.class.of_namespace(namespace).id_not_in(id).count >= MAX_FIELDS

      errors.add(
        :namespace,
        format(_('can only have a maximum of %{limit} custom fields.'), limit: MAX_FIELDS)
      )
    end

    def number_of_active_fields_per_namespace
      return if namespace.nil? || !active?
      return unless self.class.active.of_namespace(namespace).id_not_in(id).count >= MAX_ACTIVE_FIELDS

      errors.add(
        :namespace,
        format(_('can only have a maximum of %{limit} active custom fields.'), limit: MAX_ACTIVE_FIELDS)
      )
    end

    def number_of_active_fields_per_namespace_per_type
      return if namespace.nil? || !active?

      invalid_types = self.class.active.of_namespace(namespace)
                        .joins(:work_item_types)
                        .where(work_item_type_custom_fields: { work_item_type_id: work_item_type_ids })
                        .where.not(work_item_type_custom_fields: { custom_field_id: id })
                        .group('work_item_types.id, work_item_types.name')
                        .having('COUNT(*) >= ?', MAX_ACTIVE_FIELDS_PER_TYPE)
                        .pluck('work_item_types.name') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- results are limited by number of work item types

      return if invalid_types.blank?

      invalid_types.each do |type_name|
        errors.add(
          :base,
          format(_('Work item type %{work_item_type_name} can only have a maximum of %{limit} active custom fields.'),
            work_item_type_name: type_name, limit: MAX_ACTIVE_FIELDS_PER_TYPE)
        )
      end
    end

    def selectable_field_type_with_select_options
      return if field_type_single_select? || field_type_multi_select?
      return if select_options.blank?

      errors.add(:field_type, _('does not support select options.'))
    end
  end
end
