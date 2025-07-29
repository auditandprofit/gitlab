# frozen_string_literal: true

module Security
  class Attribute < ::SecApplicationRecord
    include StripAttribute

    self.table_name = 'security_attributes'

    belongs_to :namespace, optional: false
    belongs_to :security_category, class_name: 'Security::Category', optional: false

    strip_attributes! :name, :description

    enum :editable_state, Enums::Security.editable_states
    attribute :color, ::Gitlab::Database::Type::Color.new

    validates :name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :security_category_id }
    validates :description, presence: true, length: { maximum: 255 }
    validates :editable_state, presence: true
    validates :color, color: true, presence: true
  end
end
