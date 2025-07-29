# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      class LeadFormComponent < ViewComponent::Base
        include ::Gitlab::Utils::StrongMemoize
        include SafeFormatHelper
        include TrialsHelper

        delegate :page_title, :sprite_icon, to: :helpers

        attr_reader :user, :namespace_id, :eligible_namespaces

        def initialize(**kwargs)
          @user = kwargs[:user]
          @namespace_id = kwargs[:namespace_id]
          @eligible_namespaces = kwargs[:eligible_namespaces]
          @errors = kwargs[:errors]
        end

        private

        def before_render
          content_for :body_class, 'duo-pro-trials gl-bg-brand-charcoal'
        end

        def before_form_content
          # no-op
        end

        def form_data
          {
            first_name: user.first_name,
            last_name: user.last_name,
            show_name_fields: user.last_name.blank?.to_s,
            email_domain: user.email_domain,
            company_name: user.user_detail_organization,
            submit_button_text: trial_submit_text(eligible_namespaces),
            submit_path: submit_path
          }
        end

        def group_name
          (namespace_in_params || single_eligible_namespace)&.name
        end
        strong_memoize_attr :group_name

        def namespace_in_params
          return unless namespace_id

          eligible_namespaces.find_by_id(namespace_id)
        end

        def single_eligible_namespace
          return unless GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)

          eligible_namespaces.first
        end

        def submit_path
          trials_duo_pro_path(step: GitlabSubscriptions::Trials::CreateDuoProService::LEAD,
            namespace_id: params[:namespace_id]
          )
        end
      end
    end
  end
end
