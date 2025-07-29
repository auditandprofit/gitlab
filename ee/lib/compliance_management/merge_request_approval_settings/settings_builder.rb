# frozen_string_literal: true

module ComplianceManagement
  module MergeRequestApprovalSettings
    class SettingsBuilder
      def initialize(instance_value:, group_value:, project_value:)
        @instance_value = instance_value
        @group_value = group_value
        @project_value = project_value
      end

      def locked?
        return true if instance_value == false

        _, *inherited = [project_value, group_value, instance_value].compact

        inherited.any?(false)
      end

      def value
        [instance_value, group_value, project_value].compact.all?
      end

      def inherited_from
        return :instance if instance_value == false
        return :group if group_value == false && !project_value.nil?

        nil
      end

      def to_settings
        Setting.new(
          value: value,
          locked: locked?,
          inherited_from: inherited_from
        )
      end

      private

      attr_reader :instance_value, :group_value, :project_value
    end
  end
end
