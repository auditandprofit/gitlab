# frozen_string_literal: true

module Ai
  module Catalog
    class Item < ApplicationRecord
      self.table_name = "ai_catalog_items"

      validates :organization, :item_type, :description, :name, presence: true

      validates :name, length: { maximum: 255 }
      validates :description, length: { maximum: 1_024 }

      validates_inclusion_of :public, in: [true, false]
      validate :validate_public_item_cannot_become_private

      belongs_to :organization, class_name: 'Organizations::Organization', optional: false
      belongs_to :project

      has_many :versions, class_name: 'Ai::Catalog::ItemVersion', foreign_key: :ai_catalog_item_id, inverse_of: :item
      has_one :latest_version, -> { order(id: :desc) }, class_name: 'Ai::Catalog::ItemVersion',
        foreign_key: :ai_catalog_item_id, inverse_of: :item
      has_many :consumers, class_name: 'Ai::Catalog::ItemConsumer', foreign_key: :ai_catalog_item_id, inverse_of: :item

      scope :not_deleted, -> { where(deleted_at: nil) }
      scope :with_item_type, ->(item_type) { where(item_type: item_type) }

      before_destroy :prevent_deletion_if_consumers_exist

      AGENT_TYPE = :agent
      FLOW_TYPE = :flow

      enum :item_type, {
        AGENT_TYPE => 1,
        FLOW_TYPE => 2
      }

      def deleted?
        deleted_at.present?
      end

      def soft_delete
        update(deleted_at: Time.zone.now)
      end

      private

      def prevent_deletion_if_consumers_exist
        return unless consumers.any?

        errors.add(:base, 'Cannot delete an item that has consumers')
        throw :abort # rubocop:disable Cop/BanCatchThrow -- We handle soft deleting in `ee/app/services/ai/catalog/agents/destroy_service.rb`
      end

      def validate_public_item_cannot_become_private
        return unless public_changed? && public == false && public_was == true

        # TODO add support for group-level in future https://gitlab.com/gitlab-org/gitlab/-/issues/553912
        # where we would check for any consumers that are not the group, or its descendant groups or projects.
        return unless project_id.present? && consumers.not_for_projects(project_id).any?

        errors.add(:public,
          s_('AICatalog|cannot be changed from public to private as it has catalog consumers')
        )
      end
    end
  end
end
