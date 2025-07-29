# frozen_string_literal: true

module Projects
  module Security
    class PoliciesController < Projects::ApplicationController
      include GovernUsageProjectTracking
      include SecurityPoliciesPermissions

      before_action :authorize_read_security_orchestration_policies!, except: :edit
      before_action :ensure_security_policy_project_is_available!, only: :edit
      before_action :authorize_modify_security_policy!, only: :edit
      before_action :validate_policy_configuration, only: :edit

      before_action do
        push_frontend_feature_flag(:scheduled_pipeline_execution_policies, project)
        push_frontend_feature_flag(:security_policies_bypass_options, project)
        push_frontend_feature_flag(:security_policies_bypass_options_tokens_accounts, project)
        push_frontend_feature_flag(:security_policies_bypass_options_group_roles, project)
        push_frontend_feature_flag(:security_policies_split_view, project.group)
        push_frontend_feature_flag(:security_policy_approval_warn_mode, project.group)
        push_frontend_feature_flag(:flexible_scan_execution_policy, project.group)
        push_frontend_feature_flag(:security_policies_combined_list, project)
      end

      feature_category :security_policy_management
      urgency :default, [:edit]
      urgency :low, [:index, :new]
      track_govern_activity 'security_policies', :index, :edit, :new

      def index
        render :index, locals: { project: project }
      end

      def new
        @policy_type = policy_params[:type]
      end

      def edit
        @policy_name = URI.decode_www_form_component(policy_params[:id])
        @policy = policy

        render_404 if @policy.nil?
      end

      def schema
        render json: ::Security::OrchestrationPolicyConfiguration::POLICY_SCHEMA_JSON
      end

      private

      def container
        project
      end

      def policy_params
        params.permit(:type, :id)
      end

      def ensure_security_policy_project_is_available!
        render_404 if policy_configuration.blank?
      end

      def validate_policy_configuration
        @policy_type = policy_params[:type].presence&.to_sym
        result = ::Security::SecurityOrchestrationPolicies::PolicyConfigurationValidationService.new(
          policy_configuration: policy_configuration,
          type: @policy_type
        ).execute

        if result[:status] == :error
          case result[:invalid_component]
          when :policy_configuration, :parameter
            redirect_to project_security_policies_path(project), alert: result[:message]
          when :policy_project
            redirect_to project_path(policy_configuration.security_policy_management_project)
          when :policy_yaml
            policy_management_project = policy_configuration.security_policy_management_project
            policy_path = File.join(policy_management_project.default_branch, ::Security::OrchestrationPolicyConfiguration::POLICY_PATH)

            redirect_to project_blob_path(policy_management_project, policy_path), alert: result[:message]
          else
            redirect_to project_security_policies_path(project), alert: result[:message]
          end
        end
      end

      def policy
        result = ::Security::SecurityOrchestrationPolicies::FetchPolicyService.new(
          policy_configuration: policy_configuration,
          name: @policy_name,
          type: @policy_type
        ).execute

        result[:policy].presence
      end

      def policy_configuration
        @policy_configuration ||= project.security_orchestration_policy_configuration
      end
    end
  end
end
