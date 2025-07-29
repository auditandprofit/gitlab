# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Reconcile
      module Output
        # TODO this file is marked for deletion by the end of this epic https://gitlab.com/groups/gitlab-org/-/epics/17483
        class OldDesiredConfigGenerator
          include Create::CreateConstants

          # @param [RemoteDevelopment::Workspace] workspace
          # @param [Boolean] include_all_resources
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array<Hash>]
          def self.generate_desired_config(workspace:, include_all_resources:, logger:)
            config_values_extractor_result = OldConfigValuesExtractor.extract(workspace: workspace)
            config_values_extractor_result => {
              allow_privilege_escalation: TrueClass | FalseClass => allow_privilege_escalation,
              common_annotations: Hash => common_annotations,
              default_resources_per_workspace_container: Hash => default_resources_per_workspace_container,
              default_runtime_class: String => default_runtime_class,
              domain_template: String => domain_template,
              env_secret_name: String => env_secret_name,
              file_secret_name: String => file_secret_name,
              gitlab_workspaces_proxy_namespace: String => gitlab_workspaces_proxy_namespace,
              image_pull_secrets: Array => image_pull_secrets,
              labels: Hash => labels,
              max_resources_per_workspace: Hash => max_resources_per_workspace,
              network_policy_enabled: TrueClass | FalseClass => network_policy_enabled,
              network_policy_egress: Array => network_policy_egress,
              processed_devfile_yaml: String => processed_devfile_yaml,
              replicas: Integer => replicas,
              scripts_configmap_name: scripts_configmap_name,
              secrets_inventory_annotations: Hash => secrets_inventory_annotations,
              secrets_inventory_name: String => secrets_inventory_name,
              shared_namespace: String => shared_namespace,
              use_kubernetes_user_namespaces: TrueClass | FalseClass => use_kubernetes_user_namespaces,
              workspace_inventory_annotations: Hash => workspace_inventory_annotations,
              workspace_inventory_name: String => workspace_inventory_name,
            }

            desired_config = []

            append_inventory_config_map(
              desired_config: desired_config,
              name: workspace_inventory_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: common_annotations
            )

            if workspace.desired_state_terminated?
              append_inventory_config_map(
                desired_config: desired_config,
                name: secrets_inventory_name,
                namespace: workspace.namespace,
                labels: labels,
                annotations: common_annotations
              )

              return desired_config
            end

            devfile_parser_params = {
              allow_privilege_escalation: allow_privilege_escalation,
              annotations: workspace_inventory_annotations,
              default_resources_per_workspace_container: default_resources_per_workspace_container,
              default_runtime_class: default_runtime_class,
              domain_template: domain_template,
              env_secret_names: [env_secret_name],
              file_secret_names: [file_secret_name],
              labels: labels,
              name: workspace.name,
              namespace: workspace.namespace,
              replicas: replicas,
              service_account_name: workspace.name,
              use_kubernetes_user_namespaces: use_kubernetes_user_namespaces
            }

            resources_from_devfile_parser = OldDevfileParser.get_all(
              processed_devfile_yaml: processed_devfile_yaml,
              params: devfile_parser_params,
              logger: logger
            )

            # If we got no resources back from the devfile parser, this indicates some error was encountered in parsing
            # the processed_devfile. So we return an empty array which will result in no updates being applied by the
            # agent. We should not continue on and try to add anything else to the resources, as this would result
            # in an invalid configuration being applied to the cluster.
            return [] if resources_from_devfile_parser.empty?

            desired_config.append(*resources_from_devfile_parser)

            append_image_pull_secrets_service_account(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              image_pull_secrets: image_pull_secrets,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            append_network_policy(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              gitlab_workspaces_proxy_namespace: gitlab_workspaces_proxy_namespace,
              network_policy_enabled: network_policy_enabled,
              network_policy_egress: network_policy_egress,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            append_scripts_resources(
              desired_config: desired_config,
              processed_devfile_yaml: processed_devfile_yaml,
              name: scripts_configmap_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: workspace_inventory_annotations
            )

            return desired_config unless include_all_resources

            append_inventory_config_map(
              desired_config: desired_config,
              name: secrets_inventory_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: common_annotations
            )

            append_resource_quota(
              desired_config: desired_config,
              name: workspace.name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: workspace_inventory_annotations,
              max_resources_per_workspace: max_resources_per_workspace,
              shared_namespace: shared_namespace
            )

            append_secret(
              desired_config: desired_config,
              name: env_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: secrets_inventory_annotations
            )

            append_secret_data_from_variables(
              desired_config: desired_config,
              secret_name: env_secret_name,
              variables: workspace.workspace_variables.with_variable_type_environment
            )

            append_secret(
              desired_config: desired_config,
              name: file_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: secrets_inventory_annotations
            )

            append_secret_data_from_variables(
              desired_config: desired_config,
              secret_name: file_secret_name,
              variables: workspace.workspace_variables.with_variable_type_file
            )

            append_secret_data(
              desired_config: desired_config,
              secret_name: file_secret_name,
              data: { WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_NAME.to_sym => workspace.actual_state }
            )

            desired_config
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash<String, String>] labels
          # @param [Hash<String, String>] annotations
          # @return [void]
          def self.append_inventory_config_map(
            desired_config:,
            name:,
            namespace:,
            labels:,
            annotations:
          )
            extra_labels = { "cli-utils.sigs.k8s.io/inventory-id": name }

            config_map = {
              kind: "ConfigMap",
              apiVersion: "v1",
              metadata: {
                name: name,
                namespace: namespace,
                labels: labels.merge(extra_labels),
                annotations: annotations
              }
            }

            desired_config.append(config_map)

            nil
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @return [void]
          def self.append_secret(desired_config:, name:, namespace:, labels:, annotations:)
            secret = {
              kind: "Secret",
              apiVersion: "v1",
              metadata: {
                name: name,
                namespace: namespace,
                labels: labels,
                annotations: annotations
              },
              data: {}
            }

            desired_config.append(secret)

            nil
          end

          # @param [Array] desired_config
          # @param [String] secret_name
          # @param [ActiveRecord::Relation<RemoteDevelopment::WorkspaceVariable>] variables
          # @return [void]
          def self.append_secret_data_from_variables(desired_config:, secret_name:, variables:)
            data = variables.each_with_object({}) do |workspace_variable, hash|
              hash[workspace_variable.key.to_sym] = workspace_variable.value
            end

            append_secret_data(
              desired_config: desired_config,
              secret_name: secret_name,
              data: data
            )

            nil
          end

          # @param [Array] desired_config
          # @param [String] secret_name
          # @param [Hash] data
          # @return [void]
          # noinspection RubyUnusedLocalVariable -- Rubymine doesn't recognize '^' to use a variable in pattern-matching
          def self.append_secret_data(desired_config:, secret_name:, data:)
            desired_config => [
              *_,
              {
                metadata: {
                  name: ^secret_name
                },
                data: secret_data
              },
              *_
            ]

            transformed_data = data.transform_values { |value| Base64.strict_encode64(value) }

            secret_data.merge!(transformed_data)

            nil
          end

          # @param [Array] desired_config
          # @param [String] gitlab_workspaces_proxy_namespace
          # @param [String] name
          # @param [String] namespace
          # @param [Boolean] network_policy_enabled
          # @param [Array] network_policy_egress
          # @param [Hash] labels
          # @param [Hash] annotations
          # @return [void]
          def self.append_network_policy(
            desired_config:,
            name:,
            namespace:,
            gitlab_workspaces_proxy_namespace:,
            network_policy_enabled:,
            network_policy_egress:,
            labels:,
            annotations:
          )
            return unless network_policy_enabled

            egress_ip_rules = network_policy_egress

            policy_types = %w[Ingress Egress]

            proxy_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": gitlab_workspaces_proxy_namespace
              }
            }
            proxy_pod_selector = {
              matchLabels: {
                "app.kubernetes.io/name": "gitlab-workspaces-proxy"
              }
            }
            ingress = [{ from: [{ namespaceSelector: proxy_namespace_selector, podSelector: proxy_pod_selector }] }]

            kube_system_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": "kube-system"
              }
            }
            egress = [
              {
                ports: [{ port: 53, protocol: "TCP" }, { port: 53, protocol: "UDP" }],
                to: [{ namespaceSelector: kube_system_namespace_selector }]
              }
            ]
            egress_ip_rules.each do |egress_rule|
              egress.append(
                { to: [{ ipBlock: { cidr: egress_rule[:allow], except: egress_rule[:except] } }] }
              )
            end

            # Use the workspace_id as a pod selector if it is present
            workspace_id = labels.fetch(:"workspaces.gitlab.com/id", nil)
            pod_selector = {}
            # TODO: Unconditionally add this pod selector in https://gitlab.com/gitlab-org/gitlab/-/issues/535197
            if workspace_id.present?
              pod_selector[:matchLabels] = {
                "workspaces.gitlab.com/id": workspace_id
              }
            end

            network_policy = {
              apiVersion: "networking.k8s.io/v1",
              kind: "NetworkPolicy",
              metadata: {
                annotations: annotations,
                labels: labels,
                name: name,
                namespace: namespace
              },
              spec: {
                egress: egress,
                ingress: ingress,
                podSelector: pod_selector,
                policyTypes: policy_types
              }
            }

            desired_config.append(network_policy)

            nil
          end

          # @param [Array] desired_config
          # @param [String] processed_devfile_yaml
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @return [void]
          def self.append_scripts_resources(
            desired_config:,
            processed_devfile_yaml:,
            name:,
            namespace:,
            labels:,
            annotations:
          )
            desired_config => [
              *_,
              {
                kind: "Deployment",
                spec: {
                  template: {
                    spec: {
                      containers: Array => containers,
                      volumes: Array => volumes
                    }
                  }
                }
              },
              *_
            ]

            processed_devfile = YAML.safe_load(processed_devfile_yaml).deep_symbolize_keys.to_h

            devfile_commands = processed_devfile.fetch(:commands)
            devfile_events = processed_devfile.fetch(:events)

            # NOTE: This guard clause ensures we still support older running workspaces which were started before we
            #       added support for devfile postStart events. In that case, we don't want to add any resources
            #       related to the postStart script handling, because that would cause those existing workspaces
            #       to restart because the deployment would be updated.
            return unless devfile_events[:postStart].present?

            OldScriptsConfigmapAppender.append(
              desired_config: desired_config,
              name: name,
              namespace: namespace,
              labels: labels,
              annotations: annotations,
              devfile_commands: devfile_commands,
              devfile_events: devfile_events
            )

            Create::DesiredConfig::ScriptsVolumeInserter.insert(
              configmap_name: name,
              containers: containers,
              volumes: volumes
            )

            Create::DesiredConfig::KubernetesPoststartHookInserter.insert(
              containers: containers,
              devfile_commands: devfile_commands,
              devfile_events: devfile_events
            )

            nil
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Hash] max_resources_per_workspace
          # @return [void]
          def self.append_resource_quota(
            desired_config:,
            name:,
            namespace:,
            labels:,
            annotations:,
            max_resources_per_workspace:,
            shared_namespace:
          )
            return unless max_resources_per_workspace.present?
            return if shared_namespace.present?

            max_resources_per_workspace => {
              limits: {
                cpu: limits_cpu,
                memory: limits_memory
              },
              requests: {
                cpu: requests_cpu,
                memory: requests_memory
              }
            }

            resource_quota = {
              apiVersion: "v1",
              kind: "ResourceQuota",
              metadata: {
                annotations: annotations,
                labels: labels,
                name: name,
                namespace: namespace
              },
              spec: {
                hard: {
                  "limits.cpu": limits_cpu,
                  "limits.memory": limits_memory,
                  "requests.cpu": requests_cpu,
                  "requests.memory": requests_memory
                }
              }
            }

            desired_config.append(resource_quota)

            nil
          end

          # @param [Array] desired_config
          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Array] image_pull_secrets
          # @return [void]
          def self.append_image_pull_secrets_service_account(
            desired_config:,
            name:,
            namespace:,
            labels:,
            annotations:,
            image_pull_secrets:
          )
            image_pull_secrets_names = image_pull_secrets.map { |secret| { name: secret.fetch(:name) } }

            workspace_service_account_definition = {
              apiVersion: "v1",
              kind: "ServiceAccount",
              metadata: {
                name: name,
                namespace: namespace,
                annotations: annotations,
                labels: labels
              },
              automountServiceAccountToken: false,
              imagePullSecrets: image_pull_secrets_names
            }

            desired_config.append(workspace_service_account_definition)

            nil
          end

          private_class_method :append_inventory_config_map,
            :append_secret, :append_secret_data_from_variables, :append_secret_data,
            :append_network_policy, :append_resource_quota, :append_image_pull_secrets_service_account
        end
      end
    end
  end
end
