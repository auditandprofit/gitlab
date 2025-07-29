# frozen_string_literal: true

module GitlabSubscriptions
  module TrialsHelper
    def glm_source
      ::Gitlab.config.gitlab.host
    end

    def show_tier_badge_for_new_trial?(namespace, user)
      ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
        !namespace.paid? &&
        namespace.private? &&
        namespace.never_had_trial? &&
        can?(user, :read_billing, namespace)
    end

    private

    def support_link
      link_to('', Gitlab::Saas.customer_support_url, target: '_blank', rel: 'noopener noreferrer')
    end

    def errors_message(errors)
      support_message = _('Please reach out to %{support_link_start}GitLab Support%{support_link_end} for assistance')
      full_message = [support_message, errors.to_sentence.presence].compact.join(': ')

      "#{full_message}."
    end

    def trial_submit_text(eligible_namespaces)
      if GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)
        s_('Trial|Activate my trial')
      else
        s_('Trial|Continue')
      end
    end

    def namespace_selector_data(namespace_create_errors)
      {
        new_group_name: params[:new_group_name],
        # This may allow through an unprivileged submission of trial since we don't validate access on the passed in
        # namespace_id.
        # That is ok since we validate this on submission.
        initial_value: params[:namespace_id],
        namespace_create_errors: namespace_create_errors
      }
    end
  end
end
