# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class BaseCreateService
      LEAD = 'lead'
      TRIAL = 'trial'
      LEAD_FAILED = :lead_failed
      TRIAL_FAILED = :trial_failed
      NOT_FOUND = :not_found
      NO_SINGLE_NAMESPACE = :no_single_namespace

      def initialize(step:, lead_params:, trial_params:, user:)
        @step = step
        @lead_params = lead_params.to_h.symbolize_keys
        @trial_params = trial_params.to_h.symbolize_keys
        @user = user
      end

      def execute
        case step
        when LEAD
          lead_flow
        when TRIAL
          trial_flow
        else
          # some bogus request with unknown step or no step
          not_found
        end
      end

      private

      PROVIDER = 'gitlab'

      attr_reader :user, :lead_params, :trial_params, :step, :namespace

      def lead_flow
        result = lead_service_class.new.execute({ trial_user: trial_user_params })

        if result.success?
          after_lead_success_hook
        else
          after_lead_error_hook(result)
        end
      end

      def after_lead_success_hook
        track_event('lead_creation_success')

        if GitlabSubscriptions::Trials.single_eligible_namespace?(namespaces_eligible_for_trial)
          @namespace = namespaces_eligible_for_trial.first
          apply_trial_flow
        else
          # trigger new creation for next step...
          trial_selection_params = {
            step: TRIAL
          }.merge(lead_params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS))
           .merge(trial_params.slice(:namespace_id))

          ServiceResponse.error(
            message: 'Lead created, but singular eligible namespace not present',
            reason: NO_SINGLE_NAMESPACE,
            payload: { trial_selection_params: trial_selection_params }
          )
        end
      end

      def after_lead_error_hook(result)
        track_event('lead_creation_failure')
        ServiceResponse.error(message: result.message, reason: LEAD_FAILED)
      end

      def lead_service_class
        raise NoMethodError, 'Subclasses must implement the lead_service_class method'
      end

      def namespaces_eligible_for_trial
        raise NoMethodError, 'Subclasses must implement the namespaces_eligible_for_trial method'
      end

      def trial_user_params
        attrs = {
          work_email: user.email,
          uid: user.id,
          setup_for_company: user.onboarding_status_setup_for_company,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: PROVIDER
        }

        lead_params.merge(attrs)
      end

      def apply_trial_flow
        trial_params[:namespace_id] = namespace.id

        result = apply_trial_service_class.new(
          uid: user.id,
          trial_user_information: trial_user_information_params
        ).execute

        if result.success?
          after_trial_success_hook(result)
        else
          after_trial_error_hook(result)
        end
      end

      def after_trial_success_hook(result)
        track_event('trial_registration_success')
        Gitlab::Tracking.event(self.class.name, 'create_trial', namespace: namespace, user: user)

        ServiceResponse.success(
          message: 'Trial applied',
          payload: { namespace: namespace, add_on_purchase: result.payload[:add_on_purchase] }
        )
      end

      def after_trial_error_hook(result)
        track_event('trial_registration_failure')

        ServiceResponse.error(
          message: result.message,
          payload: { namespace_id: trial_params[:namespace_id] },
          reason: result.reason || TRIAL_FAILED
        )
      end

      def apply_trial_service_class
        raise NoMethodError, 'Subclasses must implement the apply_trial_service_class method'
      end

      def trial_flow
        raise NoMethodError, 'Subclasses must implement the trial_flow method'
      end

      def tracking_prefix
        raise NoMethodError, "Subclasses must implement the #{__method__} method"
      end

      def existing_namespace_flow
        @namespace = namespaces_eligible_for_trial.find_by_id(trial_params[:namespace_id])

        if namespace.present?
          apply_trial_flow
        else
          not_found
        end
      end

      def trial_user_information_params
        gl_com_params = { gitlab_com_trial: true, sync_to_gl: true }
        namespace_params = {
          namespace: namespace.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: namespace.actual_plan.name)
        }

        trial_params.except(:new_group_name, :organization_id).merge(gl_com_params).merge(namespace_params)
      end

      def not_found
        ServiceResponse.error(message: 'Not found', reason: NOT_FOUND)
      end

      def track_event(action)
        action_name = "#{tracking_prefix}#{action}"

        Gitlab::InternalEvents.track_event(action_name, user: user, namespace: namespace)
      end
    end
  end
end
