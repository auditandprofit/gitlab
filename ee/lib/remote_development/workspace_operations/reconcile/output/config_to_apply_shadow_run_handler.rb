# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        # TODO This class will be removed after the succesfull shadow run of Create::DesiredConfig::Main
        #  Epic- https://gitlab.com/groups/gitlab-org/-/epics/17483
        # This class handles the scenarios where the new desired config generator returns a different result
        # than the old one. In this case we will log a warning and use the old desired
        # config generator instead.
        class ConfigToApplyShadowRunHandler
          include WorkspaceOperationsConstants

          # @param [RemoteDevelopment::Workspace] workspace
          # @param [Array<Hash>] new_config_to_apply_array
          # @param [RemoteDevelopment::Logger] logger
          # @param [Boolean] include_all_resources
          # @return [Array<Hash>]
          def self.handle(workspace:, new_config_to_apply_array:, logger:, include_all_resources:)
            old_config_to_apply_array = OldDesiredConfigGenerator.generate_desired_config(
              workspace: workspace,
              include_all_resources: include_all_resources,
              logger: logger
            )
            diffable_new_config_to_apply_array = generate_diffable_new_config_to_apply_array(
              new_config_to_apply_array: new_config_to_apply_array
            )

            old_config_to_apply = DesiredConfig.new(desired_config_array: old_config_to_apply_array)
            new_config_to_apply = DesiredConfig.new(desired_config_array: diffable_new_config_to_apply_array)
            diff = new_config_to_apply.diff(old_config_to_apply)
            unless diff.empty?
              logger.warn(
                message: "The generated config_to_apply from Create::DesiredConfig::Main and " \
                  "OldDesiredConfigGenerator differ.",
                error_type: "workspaces_reconcile_desired_configs_differ",
                workspace_id: workspace.id,
                diff: diff
              )
            end

            old_config_to_apply_array
          end

          # @param [Array<Hash>] new_config_to_apply_array
          # @return [Array<Hash>]
          def self.generate_diffable_new_config_to_apply_array(new_config_to_apply_array:)
            new_config_to_apply_array.map do |original_resource|
              # Ensure we don't mutate the original resource, to avoid testing confusion
              resource = original_resource.deep_dup

              annotations = resource.dig(:metadata, :annotations)
              next resource unless annotations

              resource[:metadata][:annotations].delete(ANNOTATION_KEY_INCLUDE_IN_PARTIAL_RECONCILIATION)

              if resource[:kind] == "Deployment"
                resource[:spec][:template][:metadata][:annotations].delete(
                  ANNOTATION_KEY_INCLUDE_IN_PARTIAL_RECONCILIATION)
              end

              resource
            end
          end

          private_class_method :generate_diffable_new_config_to_apply_array
        end
      end
    end
  end
end
