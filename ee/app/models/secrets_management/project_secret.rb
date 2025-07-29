# frozen_string_literal: true

module SecretsManagement
  class ProjectSecret
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::Dirty

    attribute :project

    attribute :name, :string
    attribute :description, :string
    attribute :branch, :string
    attribute :environment, :string
    attribute :metadata_version, :integer, default: 0

    # We only track changes for environment and branch for policy updates
    define_attribute_methods :branch, :environment

    validates :project, presence: true
    validates :name,
      presence: true,
      length: { maximum: 255 },
      format: { with: /\A[a-zA-Z0-9_]+\z/,
                message: "can contain only letters, digits and '_'." }

    validates :branch, presence: true
    validates :environment, presence: true
    validate :ensure_active_secrets_manager

    delegate :secrets_manager, to: :project

    def initialize(attributes = {})
      super

      # Mark current state as the baseline for dirty tracking
      changes_applied
    end

    def ==(other)
      other.is_a?(self.class) && attributes == other.attributes
    end

    # Add methods to track attribute changes
    def branch=(val)
      branch_will_change! unless val == branch
      super
    end

    def environment=(val)
      environment_will_change! unless val == environment
      super
    end

    private

    def ensure_active_secrets_manager
      errors.add(:base, 'Project secrets manager is not active.') unless project.secrets_manager&.active?
    end
  end
end
