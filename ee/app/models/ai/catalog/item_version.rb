# frozen_string_literal: true

module Ai
  module Catalog
    class ItemVersion < ApplicationRecord
      include SafelyChangeColumnDefault

      AGENT_SCHEMA_VERSION = 1

      self.table_name = "ai_catalog_item_versions"

      columns_changing_default :definition

      validates :definition, :schema_version, :version, presence: true

      validates :version, length: { maximum: 50 }
      validates :version, uniqueness: { scope: :item }

      validates :definition, json_schema: { filename: 'ai_catalog_item_version_definition', size_limit: 64.kilobytes }

      validate :validate_readonly

      belongs_to :item, class_name: 'Ai::Catalog::Item',
        foreign_key: :ai_catalog_item_id, inverse_of: :versions, optional: false, autosave: true
      belongs_to :organization, class_name: 'Organizations::Organization'

      before_create :populate_organization

      def human_version
        return if version.nil?

        human_version = "v#{version}"
        return human_version if released?

        "#{human_version}-draft"
      end

      def released?
        release_date.present?
      end

      def draft?
        !released?
      end

      def readonly?
        super || release_date_was.present?
      end

      private

      def validate_readonly
        return unless readonly? && changed?

        errors.add(:base, s_('AICatalog|cannot change a released item version'))
      end

      def populate_organization
        self.organization ||= item.organization
      end
    end
  end
end
