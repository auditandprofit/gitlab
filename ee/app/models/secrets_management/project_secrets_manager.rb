# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManager < ApplicationRecord
    include Gitlab::InternalEventsTracking
    include ProjectSecretsManagers::UserHelper

    STATUSES = {
      provisioning: 0,
      active: 1,
      disabled: 2
    }.freeze

    self.table_name = 'project_secrets_managers'

    belongs_to :project

    validates :project, presence: true

    state_machine :status, initial: :provisioning do
      state :provisioning, value: STATUSES[:provisioning]
      state :active, value: STATUSES[:active]
      state :disabled, value: STATUSES[:disabled]

      event :activate do
        transition all - [:active] => :active
      end

      event :disable do
        transition active: :disabled
      end
    end

    def self.jwt_issuer
      Gitlab.config.gitlab.base_url
    end

    def self.server_url
      # Allow setting an external secrets manager URL if necessary. This is
      # useful for GitLab.Com's deployment.
      return Gitlab.config.openbao.url if Gitlab.config.has_key?("openbao") && Gitlab.config.openbao.has_key?("url")

      default_openbao_server_url
    end

    def self.default_openbao_server_url
      "#{Gitlab.config.gitlab.protocol}://#{Gitlab.config.gitlab.host}:8200"
    end
    private_class_method :default_openbao_server_url

    def ci_secrets_mount_path
      [
        namespace_path,
        "project_#{project.id}",
        'secrets',
        'kv'
      ].compact.join('/')
    end

    def ci_data_root_path
      'explicit'
    end

    def ci_data_path(secret_key = nil)
      [
        ci_data_root_path,
        secret_key
      ].compact.join('/')
    end

    def ci_full_path(secret_key)
      [
        ci_secrets_mount_path,
        'data',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def ci_metadata_full_path(secret_key)
      [
        ci_secrets_mount_path,
        'metadata',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def detailed_metadata_path(secret_key)
      [
        ci_secrets_mount_path,
        'detailed-metadata',
        ci_data_path(secret_key)
      ].compact.join('/')
    end

    def ci_auth_mount
      [
        namespace_path,
        'pipeline_jwt'
      ].compact.join('/')
    end

    def ci_auth_role
      "project_#{project.id}"
    end

    def ci_auth_type
      'jwt'
    end

    def ci_jwt(build)
      track_ci_jwt_generation(build)
      Gitlab::Ci::JwtV2.for_build(build, aud: self.class.server_url)
    end

    def ci_policy_name(environment, branch)
      if environment != "*" && branch != "*"
        ci_policy_name_combined(environment, branch)
      elsif environment != "*"
        ci_policy_name_env(environment)
      elsif branch != "*"
        ci_policy_name_branch(branch)
      else
        ci_policy_name_global
      end
    end

    def ci_policy_name_global
      [
        "project_#{project.id}",
        "pipelines",
        "global"
      ].compact.join('/')
    end

    def ci_policy_name_env(environment)
      [
        "project_#{project.id}",
        "pipelines",
        "env",
        environment.unpack1('H*')
      ].compact.join('/')
    end

    def ci_policy_name_branch(branch)
      [
        "project_#{project.id}",
        "pipelines",
        "branch",
        branch.unpack1('H*')
      ].compact.join('/')
    end

    def ci_policy_name_combined(environment, branch)
      [
        "project_#{project.id}",
        "pipelines",
        "combined",
        "env",
        environment.unpack1('H*'),
        "branch",
        branch.unpack1('H*')
      ].compact.join('/')
    end

    def ci_auth_literal_policies
      [
        # Global policy
        ci_policy_name("*", "*"),
        # Environment policy
        ci_policy_template_literal_environment,
        # Branch policy
        ci_policy_template_literal_branch,
        # Combined environment+branch policy
        ci_policy_template_literal_combined
      ]
    end

    def ci_policy_template_literal_environment
      "{{ if and (ne nil (index . \"environment\")) (ne \"\" .environment) }}" \
        "project_{{ .project_id }}/pipelines/env/{{ .environment | hex }}{{ end }}"
    end

    def ci_policy_template_literal_branch
      "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) }}" \
        "project_{{ .project_id }}/pipelines/" \
        "branch/{{ .ref | hex }}" \
        "{{ end }}"
    end

    def ci_policy_template_literal_combined
      "{{ if and (eq \"branch\" .ref_type) (ne nil (index . \"environment\")) (ne \"\" .environment) }}" \
        "project_{{ .project_id }}/pipelines/combined/" \
        "env/{{ .environment | hex}}/" \
        "branch/{{ .ref | hex }}" \
        "{{ end }}"
    end

    def ci_auth_glob_policies(environment, branch)
      ret = []

      # Add environment or branch policies. Both may be added.
      ret.append(ci_policy_template_glob_environment(environment)) if environment.include?("*")
      ret.append(ci_policy_template_glob_branch(branch)) if branch.include?("*")

      # Add the relevant combined policy. Only one will be added.
      if environment.include?("*") && branch.include?("*")
        ret.append(ci_policy_template_combined_glob_environment_glob_branch(environment,
          branch))
      end

      if environment.include?("*") && branch.exclude?("*")
        ret.append(ci_policy_template_combined_glob_environment_branch(environment,
          branch))
      end

      if environment.exclude?("*") && branch.include?("*")
        ret.append(ci_policy_template_combined_environment_glob_branch(environment,
          branch))
      end

      ret
    end

    def ci_policy_template_glob_environment(env_glob)
      # Because env_glob is converted to hex, we know it is safe to
      # directly embed in the template string. This is a bit more expensive
      # to evaluate but saves us from having to ensure we always have
      # consistent string escaping for text/template.
      env_glob_hex = env_glob.unpack1('H*')
      "{{ if and " \
        "(ne nil (index . \"environment\")) " \
        "(ne \"\" .environment) " \
        "(eq \"#{env_glob_hex}\" (.environment | hex)) }}" \
        "#{ci_policy_name_env(env_glob)}" \
        "{{end }}"
    end

    def ci_policy_template_glob_branch(branch_glob)
      # See note in ci_policy_template_glob_environment.
      branch_glob_hex = branch_glob.unpack1('H*')

      "{{ if and (eq \"branch\" .ref_type) (ne \"\" .ref) (eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
        "#{ci_policy_name_branch(branch_glob)}" \
        "{{ end }}"
    end

    def ci_policy_template_combined_glob_environment_branch(env_glob, branch_literal)
      # See note in ci_policy_template_glob_environment.
      env_glob_hex = env_glob.unpack1('H*')
      "{{ if and " \
        "(eq \"branch\" .ref_type) " \
        "(ne \"\" .ref) " \
        "(ne nil (index . \"environment\")) " \
        "(ne \"\" .environment) " \
        "(eq \"#{env_glob_hex}\" (.environment | hex)) }}" \
        "#{ci_policy_name_combined(env_glob, branch_literal)}" \
        "{{ end }}"
    end

    def ci_policy_template_combined_environment_glob_branch(env_literal, branch_glob)
      # See note in ci_policy_template_glob_environment.
      branch_glob_hex = branch_glob.unpack1('H*')
      "{{ if and " \
        "(eq \"branch\" .ref_type) " \
        "(ne \"\" .ref) " \
        "(ne nil (index . \"environment\")) " \
        "(ne \"\" .environment) " \
        "(eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
        "#{ci_policy_name_combined(env_literal, branch_glob)}" \
        "{{ end }}"
    end

    def ci_policy_template_combined_glob_environment_glob_branch(env_glob, branch_glob)
      # See note in ci_policy_template_glob_environment.
      env_glob_hex = env_glob.unpack1('H*')
      branch_glob_hex = branch_glob.unpack1('H*')
      "{{ if and " \
        "(eq \"branch\" .ref_type) " \
        "(ne \"\" .ref) " \
        "(ne \"\" .environment) " \
        "(eq \"#{env_glob_hex}\" (.environment | hex)) " \
        "(eq \"#{branch_glob_hex}\" (.ref | hex)) }}" \
        "#{ci_policy_name_combined(env_glob, branch_glob)}" \
        "{{ end }}"
    end

    def user_path(project_id)
      [
        "project_#{project_id}",
        "users",
        "direct"
      ].compact.join('/')
    end

    def role_path(project_id)
      [
        "project_#{project_id}",
        "users",
        "roles"
      ].compact.join('/')
    end

    def generate_policy_name(project_id:, principal_type:, principal_id:)
      case principal_type
      when 'User'
        [
          user_path(project_id),
          "user_#{principal_id}"
        ].compact.join('/')
      when 'Role'
        [
          role_path(project_id),
          principal_id
        ].compact.join('/')
      when 'MemberRole'
        [
          user_path(project_id),
          "member_role_#{principal_id}"
        ].compact.join('/')
      when 'Group'
        [
          user_path(project_id),
          "group_#{principal_id}"
        ].compact.join('/')
      end
    end

    private

    def namespace_path
      [
        project.namespace.type.downcase,
        project.namespace.id.to_s
      ].join('_')
    end

    def track_ci_jwt_generation(build)
      track_internal_event(
        'generate_id_token_for_secrets_manager_authentication',
        project: project,
        namespace: project.namespace,
        user: build.user
      )
    end
  end
end
