# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class InternalPoststartCommandsInserter
        include CreateConstants
        include WorkspaceOperationsConstants
        include Files
        include RemoteDevelopmentConstants

        # @param [Hash] context
        # @return [Hash]
        def self.insert(context)
          # TODO: When user-defined postStart commands are supported, add validation in previous devfile validation
          #       steps of the ".../workspace_operations/create" ROP chain.
          #       See: https://gitlab.com/gitlab-org/gitlab/-/issues/505988

          context => {
            processed_devfile: {
              components: Array => components,
              commands: Array => commands,
              events: {
                postStart: Array => poststart_events
              }
            },
            params: {
              project: project,
              project_ref: String => project_ref,
            },
            volume_mounts: {
              data_volume: { path: String => volume_path }
            },
          }

          project_cloning_successful_file = "#{volume_path}/#{PROJECT_CLONING_SUCCESSFUL_FILE_NAME}"
          clone_dir = "#{volume_path}/#{project.path}"
          project_url = project.http_url_to_repo

          clone_depth_option = workspaces_shallow_clone_project_feature_enabled?(project) ? CLONE_DEPTH_OPTION : ""

          # Add the clone_project event
          clone_project_command_id = "gl-clone-project-command"
          clone_project_script =
            format(
              INTERNAL_POSTSTART_COMMAND_CLONE_PROJECT_SCRIPT,
              project_cloning_successful_file: Shellwords.shellescape(project_cloning_successful_file),
              clone_dir: Shellwords.shellescape(clone_dir),
              project_ref: Shellwords.shellescape(project_ref),
              project_url: Shellwords.shellescape(project_url),
              clone_depth_option: clone_depth_option
            )

          # NOTE: We will always have exactly one main_component found, because we have already
          #       validated this in devfile processing
          main_component = components.find do |component|
            # NOTE: We can't use pattern matching here, because constants can't be used in pattern matching.
            #       Otherwise, we could do this all in a single pattern match.
            component.dig(:attributes, MAIN_COMPONENT_INDICATOR_ATTRIBUTE.to_sym)
          end

          main_component => { name: String => main_component_name }

          commands << {
            id: clone_project_command_id,
            exec: {
              commandLine: clone_project_script,
              component: main_component_name,
              label: INTERNAL_BLOCKING_COMMAND_LABEL
            }
          }

          unless clone_depth_option.empty?
            # Add the clone_unshallow event
            clone_unshallow_command_id = "gl-clone-unshallow-command"
            clone_unshallow_script =
              format(
                INTERNAL_POSTSTART_COMMAND_CLONE_UNSHALLOW_SCRIPT,
                project_cloning_successful_file: Shellwords.shellescape(project_cloning_successful_file),
                clone_dir: Shellwords.shellescape(clone_dir)
              )

            commands << {
              id: clone_unshallow_command_id,
              exec: {
                commandLine: clone_unshallow_script,
                component: main_component_name,
                label: INTERNAL_BLOCKING_COMMAND_LABEL
              }
            }
          end

          # Add the start_sshd event
          start_sshd_command_id = "gl-start-sshd-command"
          commands << {
            id: start_sshd_command_id,
            exec: {
              commandLine: INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT,
              component: main_component_name,
              label: INTERNAL_BLOCKING_COMMAND_LABEL
            }
          }

          # Add the start_vscode event
          start_vscode_command_id = "gl-init-tools-command"
          commands << {
            id: start_vscode_command_id,
            exec: {
              commandLine: INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT,
              component: main_component_name,
              label: INTERNAL_BLOCKING_COMMAND_LABEL
            }
          }

          # Add the sleep_until_container_is_running event
          sleep_until_container_is_running_command_id = "gl-sleep-until-container-is-running-command"
          sleep_until_container_is_running_script =
            format(
              INTERNAL_POSTSTART_COMMAND_SLEEP_UNTIL_WORKSPACE_IS_RUNNING_SCRIPT,
              workspace_reconciled_actual_state_file_path: WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_PATH
            )

          commands << {
            id: sleep_until_container_is_running_command_id,
            exec: {
              commandLine: sleep_until_container_is_running_script,
              component: main_component_name,
              label: INTERNAL_COMMAND_LABEL
            }
          }

          commands_to_prepend = [
            clone_project_command_id,
            start_sshd_command_id,
            start_vscode_command_id,
            sleep_until_container_is_running_command_id
          ]

          # Insert the unshallow command after the clone command, if the FF is enabled and clone_depth_option is set.
          commands_to_prepend.insert(1, clone_unshallow_command_id) unless clone_depth_option.empty?

          # Prepend internal commands so they are executed before any user-defined poststart events.
          poststart_events.prepend(*commands_to_prepend)

          context
        end

        # @param [Project] project
        # @return [TrueClass, FalseClass]
        def self.workspaces_shallow_clone_project_feature_enabled?(project)
          Feature.enabled?(:workspaces_shallow_clone_project, project)
        end

        private_class_method :workspaces_shallow_clone_project_feature_enabled?
      end
    end
  end
end
