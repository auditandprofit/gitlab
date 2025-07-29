# frozen_string_literal: true

module EE
  module Ci
    module RetryPipelineService
      extend ::Gitlab::Utils::Override

      override :check_access
      def check_access(pipeline)
        begin
          ::Users::IdentityVerification::AuthorizeCi.new(user: current_user, project: project).authorize_run_jobs!
        rescue ::Users::IdentityVerification::Error => e
          return ServiceResponse.error(message: e.message, http_status: :forbidden)
        end

        super
      end

      private

      override :builds_relation
      def builds_relation(pipeline)
        super.eager_load_tags
      end

      override :can_be_retried?
      def can_be_retried?(build)
        result = runners_availability_checker.check(build.build_matcher)
        super && result.available?
      end

      def runners_availability_checker
        ::Gitlab::Ci::RunnersAvailabilityChecker.instance_for(project)
      end
    end
  end
end
