# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      class LeadFormWithErrorsComponent < LeadFormComponent
        extend ::Gitlab::Utils::Override

        # @param [Form Params] form params for the form on submission failure
        # @param [errors] possible errors from backend
        def initialize(**kwargs)
          super

          @form_params = kwargs[:form_params]
          @errors = kwargs[:errors]
        end

        private

        attr_reader :form_params, :errors

        override :before_form_content
        def before_form_content
          render FormErrorsComponent.new(errors: errors)
        end

        override :form_data
        def form_data
          super.merge(form_params_for_submission_failure)
        end

        def form_params_for_submission_failure
          form_params.slice(
            :first_name, :last_name, :company_name, :phone_number, :country, :state
          ).to_h.symbolize_keys
        end
      end
    end
  end
end
