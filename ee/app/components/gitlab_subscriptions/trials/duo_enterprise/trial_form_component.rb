# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      class TrialFormComponent < ViewComponent::Base
        include TrialFormDisplayUtilities

        def initialize(**kwargs)
          @eligible_namespaces = kwargs[:eligible_namespaces]
          @params = kwargs[:params]
        end

        private

        attr_reader :eligible_namespaces, :params

        delegate :page_title, :sprite_icon, :gitlab_ui_form_for, to: :helpers

        def before_render
          content_for :body_class, 'duo-enterprise-trials gl-bg-brand-charcoal'
        end

        def before_form_content
          # no op
        end

        def submit_path
          trials_duo_enterprise_path(step: GitlabSubscriptions::Trials::CreateDuoEnterpriseService::TRIAL)
        end

        def trial_namespace_selector_data
          {
            initial_value: params[:namespace_id],
            any_trial_eligible_namespaces: eligible_namespaces.any?.to_s,
            items: format_namespaces_for_selector(eligible_namespaces).to_json
          }
        end
      end
    end
  end
end
