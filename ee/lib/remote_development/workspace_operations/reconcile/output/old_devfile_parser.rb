# frozen_string_literal: true

require 'devfile'

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        class OldDevfileParser
          include WorkspaceOperationsConstants
          include Create::CreateConstants

          # @param [String] processed_devfile_yaml
          # @param [Hash] params
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array<Hash>]
          def self.get_all(processed_devfile_yaml:, params:, logger:)
            params => {
              name: String => name,
              namespace: String => namespace,
              replicas: Integer => replicas,
              domain_template: String => domain_template,
              labels: Hash => labels,
              annotations: Hash => annotations,
              env_secret_names: Array => env_secret_names,
              file_secret_names: Array => file_secret_names,
              service_account_name: String => service_account_name,
              default_resources_per_workspace_container: Hash => default_resources_per_workspace_container,
              allow_privilege_escalation: TrueClass | FalseClass => allow_privilege_escalation,
              use_kubernetes_user_namespaces: TrueClass | FalseClass => use_kubernetes_user_namespaces,
              default_runtime_class: String => default_runtime_class
            }

            begin
              workspace_resources_yaml = Devfile::Parser.get_all(
                processed_devfile_yaml,
                name,
                namespace,
                YAML.dump(labels.deep_stringify_keys),
                YAML.dump(annotations.deep_stringify_keys),
                replicas,
                domain_template,
                'none'
              )
            rescue Devfile::CliError => e
              error_message = <<~MSG.squish
                #{e.class}: A non zero return code was observed when invoking the devfile CLI
                executable from the devfile gem.
              MSG
              logger.warn(
                message: error_message,
                error_type: 'reconcile_devfile_parser_error',
                workspace_name: name,
                workspace_namespace: namespace,
                devfile_parser_error: e.message
              )
              return []
            rescue StandardError => e
              error_message = <<~MSG.squish
                #{e.class}: An unrecoverable error occurred when invoking the devfile gem,
                this may hint that a gem with a wrong architecture is being used.
              MSG
              logger.warn(
                message: error_message,
                error_type: 'reconcile_devfile_parser_error',
                workspace_name: name,
                workspace_namespace: namespace,
                devfile_parser_error: e.message
              )
              return []
            end

            workspace_resources = YAML.load_stream(workspace_resources_yaml).map(&:deep_symbolize_keys)

            workspace_resources = set_host_users(
              workspace_resources: workspace_resources,
              use_kubernetes_user_namespaces: use_kubernetes_user_namespaces
            )
            workspace_resources = set_runtime_class(
              workspace_resources: workspace_resources,
              runtime_class_name: default_runtime_class
            )
            workspace_resources = set_security_context(
              workspace_resources: workspace_resources,
              allow_privilege_escalation: allow_privilege_escalation
            )
            workspace_resources = patch_default_resources(
              workspace_resources: workspace_resources,
              default_resources_per_workspace_container:
                default_resources_per_workspace_container
            )
            workspace_resources = inject_secrets(
              workspace_resources: workspace_resources,
              env_secret_names: env_secret_names,
              file_secret_names: file_secret_names
            )

            set_service_account(
              workspace_resources: workspace_resources,
              service_account_name: service_account_name
            )
          end

          # @param [Array<Hash>] workspace_resources
          # @param [Boolean] use_kubernetes_user_namespaces
          # @return [Array<Hash>]
          def self.set_host_users(workspace_resources:, use_kubernetes_user_namespaces:)
            # NOTE: Not setting the use_kubernetes_user_namespaces always since setting it now would require migration
            # from old config version to a new one. Set this field always
            # when a new devfile parser is created for some other reason.
            return workspace_resources unless use_kubernetes_user_namespaces

            workspace_resources.each do |workspace_resource|
              next unless workspace_resource[:kind] == 'Deployment'

              workspace_resource[:spec][:template][:spec][:hostUsers] = use_kubernetes_user_namespaces
            end
            workspace_resources
          end

          # @param [Array<Hash>] workspace_resources
          # @param [String] runtime_class_name
          # @return [Array<Hash>]
          def self.set_runtime_class(workspace_resources:, runtime_class_name:)
            # NOTE: Not setting the runtime_class_name always since changing it now would require migration
            # from old config version to a new one. Update this field to `runtime_class_name.presence`
            # when a new devfile parser is created for some other reason.
            return workspace_resources if runtime_class_name.empty?

            workspace_resources.each do |workspace_resource|
              next unless workspace_resource[:kind] == 'Deployment'

              workspace_resource[:spec][:template][:spec][:runtimeClassName] = runtime_class_name
            end
            workspace_resources
          end

          # Devfile library allows specifying the security context of pods/containers as mentioned in
          # https://github.com/devfile/api/issues/920 through `pod-overrides` and `container-overrides` attributes.
          # However, https://github.com/devfile/library/pull/158 which is implementing this feature,
          # is not part of v2.2.0 which is the latest release of the devfile which is being used in the devfile-gem.
          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409189
          #       Once devfile library releases a new version, update the devfile-gem and move
          #       the logic of setting the security context as part of workspace creation.

          # @param [Array<Hash>] workspace_resources
          # @param [Boolean] allow_privilege_escalation
          # @param [Boolean] use_kubernetes_user_namespaces
          # @return [Array<Hash>]
          def self.set_security_context(
            workspace_resources:,
            allow_privilege_escalation:
          )
            workspace_resources.each do |workspace_resource|
              next unless workspace_resource[:kind] == 'Deployment'

              pod_security_context = {
                runAsNonRoot: true,
                runAsUser: RUN_AS_USER,
                fsGroup: 0,
                fsGroupChangePolicy: 'OnRootMismatch'
              }
              container_security_context = {
                allowPrivilegeEscalation: allow_privilege_escalation,
                privileged: false,
                runAsNonRoot: true,
                runAsUser: RUN_AS_USER
              }

              pod_spec = workspace_resource[:spec][:template][:spec]
              # Explicitly set security context for the pod
              pod_spec[:securityContext] = pod_security_context
              # Explicitly set security context for all containers
              pod_spec[:containers].each do |container|
                container[:securityContext] = container_security_context
              end
              # Explicitly set security context for all init containers
              pod_spec[:initContainers].each do |init_container|
                init_container[:securityContext] = container_security_context
              end
            end
            workspace_resources
          end

          # @param [Array<Hash>] workspace_resources
          # @param [Hash] default_resources_per_workspace_container
          # @return [Array<Hash>]
          def self.patch_default_resources(workspace_resources:, default_resources_per_workspace_container:)
            workspace_resources.each do |workspace_resource|
              next unless workspace_resource.fetch(:kind) == 'Deployment'

              pod_spec = workspace_resource.fetch(:spec).fetch(:template).fetch(:spec)

              container_types = [:initContainers, :containers]
              container_types.each do |container_type|
                # the purpose of this deep_merge is to ensure
                # the values from the devfile override any defaults defined at the agent
                pod_spec.fetch(container_type).each do |container|
                  container
                    .fetch(:resources, {})
                    .deep_merge!(default_resources_per_workspace_container) { |_, val, _| val }
                end
              end
            end
            workspace_resources
          end

          # @param [Array<Hash>] workspace_resources
          # @param [Array<String>] env_secret_names
          # @param [Array<String>] file_secret_names
          # @return [Array<Hash>]
          def self.inject_secrets(workspace_resources:, env_secret_names:, file_secret_names:)
            workspace_resources.each do |workspace_resource|
              next unless workspace_resource.fetch(:kind) == 'Deployment'

              volume = {
                name: VARIABLES_VOLUME_NAME,
                projected: {
                  defaultMode: VARIABLES_VOLUME_DEFAULT_MODE,
                  sources: file_secret_names.map { |name| { secret: { name: name } } }
                }
              }

              volume_mount = {
                name: VARIABLES_VOLUME_NAME,
                mountPath: VARIABLES_VOLUME_PATH
              }

              env_from = env_secret_names.map { |v| { secretRef: { name: v } } }

              pod_spec = workspace_resource.fetch(:spec).fetch(:template).fetch(:spec)
              pod_spec.fetch(:volumes) << volume unless file_secret_names.empty?

              pod_spec.fetch(:initContainers).each do |init_container|
                init_container.fetch(:volumeMounts) << volume_mount unless file_secret_names.empty?
                init_container[:envFrom] = env_from unless env_secret_names.empty?
              end

              pod_spec.fetch(:containers).each do |container|
                container.fetch(:volumeMounts) << volume_mount unless file_secret_names.empty?
                container[:envFrom] = env_from unless env_secret_names.empty?
              end
            end
            workspace_resources
          end

          # @param [Array<Hash>] workspace_resources
          # @param [String] service_account_name
          # @return [Array<Hash>]
          def self.set_service_account(workspace_resources:, service_account_name:)
            workspace_resources.each do |workspace_resource|
              next unless workspace_resource.fetch(:kind) == 'Deployment'

              workspace_resource[:spec][:template][:spec][:serviceAccountName] = service_account_name
            end
            workspace_resources
          end
        end
      end
    end
  end
end
