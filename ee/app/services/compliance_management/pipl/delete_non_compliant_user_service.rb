# frozen_string_literal: true

module ComplianceManagement
  module Pipl
    class DeleteNonCompliantUserService
      include ComplianceManagement::Pipl::UserConcern

      def initialize(pipl_user:, current_user:)
        @pipl_user = pipl_user
        @current_user = current_user
      end

      def execute
        authorization_result = authorize!
        return authorization_result if authorization_result

        validation_result = validate!
        return validation_result if validation_result

        if user_has_active_public_project?(pipl_user.user)
          pipl_user.update(state: "deletion_needs_to_be_reviewed")
          return error_response("User has active public projects and cannot be deleted." \
            "Please unlink the public projects or move the user the paid namespace")
        end

        pipl_user.user.delete_async(deleted_by: current_user,
          params: { hard_delete: false, skip_authorization: true }.stringify_keys)

        ServiceResponse.success
      end

      private

      attr_reader :pipl_user, :current_user

      delegate :user, to: :pipl_user, private: true

      def authorize!
        unless ::Gitlab::Saas.feature_available?(:pipl_compliance)
          return error_response("Pipl Compliance is not available on this instance")
        end

        return if Ability.allowed?(current_user, :delete_pipl_user, pipl_user)

        error_response("You don't have the required permissions to perform this action or this feature is disabled")
      end

      def validate!
        unless pipl_user.deletion_threshold_met?
          return error_response("Pipl deletion threshold has not been exceeded for user: #{user.id}")
        end

        error_response("User is not blocked") unless user.blocked?
      end

      def error_response(message)
        ServiceResponse.error(message: message)
      end

      def user_has_active_public_project?(user)
        # rubocop: disable CodeReuse/ActiveRecord -- This is a small check and adding a new scope for the same is a bit of overhead
        public_projects = user.personal_projects.where(visibility_level: Gitlab::VisibilityLevel::PUBLIC).select(:id)

        return false unless public_projects.exists?

        return true if ProjectStatistics.for_project_ids(public_projects).where("commit_count > ?", 5).exists?

        # rubocop: enable CodeReuse/ActiveRecord

        false
      end
    end
  end
end
