# frozen_string_literal: true

module Security
  module PipelineExecutionPolicy
    class VariablesOverride
      def initialize(project:, job_options:)
        @project = project
        @override_settings = job_options&.dig(:execution_policy_variables_override)
        @policy_job = job_options&.dig(:execution_policy_job)
      end

      # This is the original way of enforcing policy variables.
      # It's used when policies don't specify the `variables_override` option.
      def apply_highest_precedence(variables, yaml_variables)
        return variables unless apply_highest_precedence?

        yaml_variable_keys = yaml_variables.pluck(:key).to_set # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- this is not a DB query
        variables.reject { |var| yaml_variable_keys.include?(var.key) }.concat(yaml_variables)
      end

      def apply_variables_override(variables)
        return variables unless apply_variables_override?

        if override_settings[:allowed]
          override_with_denylist(variables)
        else
          override_with_allowlist(variables)
        end
      end

      private

      attr_reader :project, :override_settings, :policy_job

      def policy_job?
        !!policy_job
      end

      def exceptions
        override_settings[:exceptions] || []
      end

      def apply_highest_precedence?
        policy_job? && !apply_variables_override?
      end

      def apply_variables_override?
        policy_job? && override_settings
      end

      # allowed:true + exceptions: [...]
      def override_with_denylist(variables)
        return variables if exceptions.blank?

        variables.reject { |var| exceptions.include?(var.key) }
      end

      # allowed:false + exceptions: [...]
      def override_with_allowlist(variables)
        exceptions.each_with_object(::Gitlab::Ci::Variables::Collection.new) do |var_key, allowlist|
          allowlist.append(variables[var_key]) if variables[var_key]
        end
      end
    end
  end
end
