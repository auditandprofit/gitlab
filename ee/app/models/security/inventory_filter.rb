# frozen_string_literal: true

module Security
  class InventoryFilter < ::SecApplicationRecord
    self.table_name = 'security_inventory_filters'

    scope :by_project_id, ->(project_id) { where(project_id: project_id) }

    belongs_to :project
    validates :archived, allow_nil: false, inclusion: { in: [true, false] }

    # Analyzer statuses
    Enums::Security.extended_analyzer_types.each_key do |analyzer_type|
      enum analyzer_type.to_sym, Enums::Security.analyzer_statuses, prefix: true
      validates analyzer_type, presence: true
    end

    # vulnerability counts
    validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :critical, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :high, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :medium, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :low, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :info, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :unknown, presence: true, numericality: { greater_than_or_equal_to: 0 }

    validates :project_name, presence: true
    validates :traversal_ids, presence: true
  end
end
