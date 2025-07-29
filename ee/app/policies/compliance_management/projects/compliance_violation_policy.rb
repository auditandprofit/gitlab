# frozen_string_literal: true

module ComplianceManagement
  module Projects
    class ComplianceViolationPolicy < BasePolicy
      condition(:has_access_to_violations_on_group) do
        Ability.allowed?(@user, :read_compliance_violations_report, @subject.project.group)
      end

      condition(:has_access_to_violations_on_project) do
        Ability.allowed?(@user, :read_compliance_violations_report, @subject.project)
      end

      rule { has_access_to_violations_on_group | has_access_to_violations_on_project }.policy do
        enable :read_compliance_violations_report
        enable :create_note
      end
    end
  end
end
