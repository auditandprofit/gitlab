# frozen_string_literal: true

module WorkItems
  class Color < ApplicationRecord
    self.table_name = 'work_item_colors'

    DEFAULT_COLOR = ::Gitlab::Color.of('#1068bf')
    attribute :color, ::Gitlab::Database::Type::Color.new, default: DEFAULT_COLOR

    validates :color, color: true, presence: true

    # namespace is required as the sharding key
    belongs_to :namespace, inverse_of: :work_items_colors
    belongs_to :work_item, foreign_key: 'issue_id', inverse_of: :color

    before_validation :set_namespace

    def text_color
      color.contrast
    end

    private

    def set_namespace
      return if work_item.blank?
      return if work_item.namespace == namespace

      self.namespace = work_item.namespace
    end
  end
end
