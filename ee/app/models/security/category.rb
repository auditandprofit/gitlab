# frozen_string_literal: true

module Security
  class Category < ::SecApplicationRecord
    self.table_name = 'security_categories'

    belongs_to :namespace, optional: false

    enum :editable_state, Enums::Security.editable_states

    enum :template_type, {
      business_impact: 0,
      business_unit: 1,
      application: 2,
      location: 3,
      exposure: 4
    }

    validates :name, presence: true
    validates :editable_state, presence: true
    validates :multiple_selection, inclusion: { in: [true, false] }
    validates :name, uniqueness: { scope: :namespace_id }, length: { maximum: 255 }
    validates :description, length: { maximum: 255 }, allow_blank: true
    validate :valid_namespace

    private

    def valid_namespace
      return if namespace&.root? && namespace.group_namespace?

      errors.add(:namespace, _('must be a root group.'))
    end
  end
end
