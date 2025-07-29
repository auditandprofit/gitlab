# frozen_string_literal: true

module AuditEvents
  module Group
    class ExternalStreamingDestination < ApplicationRecord
      include Limitable
      include ExternallyStreamable
      include LegacyDestinationMappable
      include Activatable

      MAXIMUM_NAMESPACE_FILTER_COUNT = 5

      self.limit_name = 'external_audit_event_destinations'
      self.limit_scope = :group
      self.table_name = 'audit_events_group_external_streaming_destinations'

      belongs_to :group, class_name: '::Group', inverse_of: :audit_events
      validate :top_level_group?
      validates :name, uniqueness: { scope: [:category, :group_id] }

      has_many :event_type_filters, class_name: 'AuditEvents::Group::EventTypeFilter'
      has_many :namespace_filters, class_name: 'AuditEvents::Group::NamespaceFilter'

      validate :no_more_than_5_namespace_filters?

      private

      def no_more_than_5_namespace_filters?
        return unless namespace_filters.count > MAXIMUM_NAMESPACE_FILTER_COUNT

        errors.add(:namespace_filters,
          format(_("are limited to %{max_count} per destination"), max_count: MAXIMUM_NAMESPACE_FILTER_COUNT))
      end

      def top_level_group?
        errors.add(:group, 'must not be a subgroup. Use a top-level group.') if group.subgroup?
      end
    end
  end
end
