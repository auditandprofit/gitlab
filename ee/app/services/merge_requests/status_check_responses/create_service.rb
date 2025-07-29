# frozen_string_literal: true

module MergeRequests
  module StatusCheckResponses
    class CreateService < BaseProjectService
      def execute(merge_request)
        unless current_user.can?(:provide_status_check_response, merge_request)
          return ServiceResponse.error(message: 'Not Found', reason: :not_found)
        end

        response = merge_request.status_check_responses.new(
          external_status_check: external_status_check,
          status: status,
          sha: sha
        )

        if response.save
          log_audit_event(merge_request)

          ServiceResponse.success(payload: { status_check_response: response })
        else
          ServiceResponse.error(
            message: 'Failed to create status check response',
            payload: { errors: response.errors.full_messages },
            reason: :bad_request
          )
        end
      end

      private

      def status
        params[:status]
      end

      def sha
        params[:sha]
      end

      def external_status_check
        params[:external_status_check]
      end

      def log_audit_event(merge_request)
        ::Gitlab::Audit::Auditor.audit(
          name: 'status_check_response_update',
          author: current_user,
          scope: project,
          target: merge_request,
          message: "Updated response for status check #{external_status_check.name} to #{status}",
          additional_details: {
            external_status_check_id: external_status_check.id,
            external_status_check_name: external_status_check.name,
            status: status,
            sha: sha,
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid
          }
        )
      end
    end
  end
end
