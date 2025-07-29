# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class WelcomeCreateService
      EXPERIMENT_SAAS_TRIAL_PRODUCT_INTERACTION = 'Experiment - SaaS Trial'
      private_constant :EXPERIMENT_SAAS_TRIAL_PRODUCT_INTERACTION

      include Gitlab::Allowable

      def initialize(params:, user:, namespace_id: nil, project_id: nil, lead_created: false)
        @params = params
        @user = user
        @namespace_id = namespace_id
        @project_id = project_id
        @lead_created = lead_created
      end

      def execute
        if namespace_id.blank?
          return not_found unless user.can_create_group?

          @namespace = create_group
        else
          @namespace = Namespace.find(namespace_id)
          return not_found unless GitlabSubscriptions::Trials.namespace_eligible?(namespace)
          return not_found unless user.can?(:admin_namespace, namespace)
        end

        return error unless namespace.persisted?

        if project_id.blank?
          return not_found unless user.can_create_project?

          @project = create_project
        else
          @project = Project.find(project_id)
          return not_found unless user.can?(:admin_project, project)
        end

        return error unless project.persisted?

        setup_trial
      end

      private

      attr_reader :user, :params, :namespace, :project, :namespace_id, :project_id, :lead_created

      def create_group
        name = ActionController::Base.helpers.sanitize(params[:group_name], tags: [])
        group_params = {
          name: name,
          path: Namespace.clean_path(name.parameterize),
          organization_id: params[:organization_id]
        }

        response = Groups::CreateService.new(user, group_params).execute
        namespace = response[:group]

        # We need to stick to the primary database in order to allow the following request
        # fetch the namespace from an up-to-date replica or a primary database.
        ::Namespace.sticking.stick(:namespace, namespace.id) if response.success?
        namespace
      end

      def create_project
        project_params = {
          name: ActionController::Base.helpers.sanitize(params[:project_name], tags: []),
          namespace_id: namespace.id,
          organization_id: namespace.organization_id
        }

        Projects::CreateService.new(user, project_params).execute
      end

      def submit_lead
        GitlabSubscriptions::CreateLeadService.new.execute(trial_user: lead_params)
      end

      def submit_trial
        result = GitlabSubscriptions::Trials::ApplyTrialService.new(uid: user.id,
          trial_user_information: trial_params).execute
        result[:add_on_purchase]
      end

      def setup_trial
        @lead_created = submit_lead.success? unless lead_created

        return error unless lead_created

        add_on_purchase = submit_trial

        return error unless add_on_purchase.present?

        success(add_on_purchase)
      end

      def trial_params
        gl_com_params = { gitlab_com_trial: true, sync_to_gl: true }
        namespace_params = {
          namespace_id: namespace.id,
          namespace: namespace.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: namespace.actual_plan.name)
        }

        params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id)
          .merge(gl_com_params, namespace_params).to_h.symbolize_keys
      end

      def lead_params
        attrs = {
          work_email: user.email,
          uid: user.id,
          setup_for_company: false,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab',
          product_interaction: EXPERIMENT_SAAS_TRIAL_PRODUCT_INTERACTION
        }

        params.slice(
          *::Onboarding::StatusPresenter::GLM_PARAMS,
          :company_name, :first_name, :last_name, :country, :state
        ).merge(attrs)
      end

      def model_errors
        {
          group_name: namespace.try(:errors).try(:full_messages).try(:to_sentence),
          project_name: project.try(:errors).try(:full_messages).try(:to_sentence)
        }.select { |_m, e| e.present? }
      end

      def not_found
        ServiceResponse.error(message: 'Not found', reason: :not_found)
      end

      def progress
        {
          namespace_id: namespace.try(:id),
          project_id: project.try(:id),
          lead_created: lead_created
        }
      end

      def failure_stage
        stages = %w[namespace project lead application]
        index = [!!namespace.try(:persisted?), !!project.try(:persisted?), lead_created, false].find_index(false)

        stages[index]
      end

      def error
        ServiceResponse.error(
          message: "Trial creation failed in #{failure_stage} stage",
          payload: progress.merge({ model_errors: model_errors })
        )
      end

      def success(add_on_purchase)
        ServiceResponse.success(
          message: 'Trial applied',
          payload: { namespace_id: namespace.id, add_on_purchase: add_on_purchase }
        )
      end
    end
  end
end
