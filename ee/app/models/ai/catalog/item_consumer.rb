# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumer < ApplicationRecord
      self.table_name = "ai_catalog_item_consumers"

      validates :enabled, :locked, inclusion: { in: [true, false] }

      validates :pinned_version_prefix, length: { maximum: 50 }

      validate :validate_exactly_one_sharding_key_present

      belongs_to :item, class_name: 'Ai::Catalog::Item',
        foreign_key: :ai_catalog_item_id, inverse_of: :consumers, optional: false

      belongs_to :organization, class_name: 'Organizations::Organization'
      belongs_to :group
      belongs_to :project

      scope :not_for_projects, ->(project) { where.not(project: project) }

      private

      def validate_exactly_one_sharding_key_present
        return if [organization, group, project].compact.one?

        errors.add(:base, 'The item must belong to only one organization, group, or project')
      end
    end
  end
end
