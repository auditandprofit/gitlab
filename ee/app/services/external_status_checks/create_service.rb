# frozen_string_literal: true

module ExternalStatusChecks
  class CreateService < BaseService
    attr_reader :skip_authorization

    def execute(skip_authorization: false)
      return access_denied_error unless skip_authorization || can_create_status_check?

      rule = container.external_status_checks.new(
        name: params[:name],
        external_url: params[:external_url],
        shared_secret: params[:shared_secret],
        protected_branch_ids: params[:protected_branch_ids]
      )

      if with_audit_logged(rule, 'create_status_check') { rule.save }
        ServiceResponse.success(payload: { rule: rule })
      else
        ServiceResponse.error(
          message: 'Failed to create external status check',
          payload: { errors: rule.errors.full_messages },
          http_status: :unprocessable_entity
        )
      end
    end

    def can_create_status_check?
      current_user.can?(:manage_merge_request_settings, container)
    end

    def access_denied_error
      ServiceResponse.error(
        message: 'Failed to create external status check',
        payload: { errors: ['Not allowed'] },
        reason: :access_denied
      )
    end
  end
end
