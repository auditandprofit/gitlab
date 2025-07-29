# frozen_string_literal: true

module EE
  module GroupDeletionSchedule
    extend ActiveSupport::Concern
    include SecurityOrchestrationHelper

    prepended do
      validate :excludes_security_policy_projects, if: :group, on: :create
    end

    private

    def excludes_security_policy_projects
      return unless security_configurations_preventing_group_deletion(group).exists?

      errors.add(:base,
        s_('SecurityOrchestration|Group cannot be deleted because it has projects ' \
          'that are linked as a security policy project')
      )
    end
  end
end
