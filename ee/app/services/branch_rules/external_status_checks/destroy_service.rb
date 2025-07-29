# frozen_string_literal: true

module BranchRules
  module ExternalStatusChecks
    class DestroyService < BaseService
      private

      def action_name
        'destroy'
      end

      def execute_on_branch_rule
        ::ExternalStatusChecks::DestroyService.new(
          container: project,
          current_user: current_user
        ).execute(external_status_check, skip_authorization: true)
      rescue ActiveRecord::RecordNotFound => exception
        ServiceResponse.error(
          message: exception.message,
          payload: { errors: ['Not found'] },
          reason: :not_found
        )
      end
      alias_method :execute_on_all_branches_rule, :execute_on_branch_rule

      def external_status_check
        @external_status_check ||= project.external_status_checks.find(params[:id])
      end

      def permitted_params
        [:id]
      end
    end
  end
end
