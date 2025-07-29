# frozen_string_literal: true

module EE
  module Applications
    module CreateService
      extend ::Gitlab::Utils::Override

      def self.prepended(base)
        base.singleton_class.prepend(ClassMethods)
      end

      module ClassMethods
        extend ::Gitlab::Utils::Override

        # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Must be instance-level
        override :disable_ropc_available?
        def disable_ropc_available?
          ::Gitlab::Saas.feature_available?(:disable_ropc_for_new_applications) &&
            ::Feature.enabled?(:disable_ropc_for_new_applications)
        end
        # rubocop:enable Gitlab/FeatureFlagWithoutActor
      end

      override :execute
      def execute(request)
        super.tap do |application|
          audit_oauth_application_creation(application, request.remote_ip)
        end
      end

      private

      def audit_oauth_application_creation(application, ip_address)
        entity = application.owner || current_user

        ::Gitlab::Audit::Auditor.audit(
          name: 'oauth_application_created',
          author: current_user,
          scope: entity,
          target: application,
          message: 'OAuth application added',
          additional_details: {
            application_name: application.name,
            application_id: application.id,
            scopes: application.scopes.to_a,
            redirect_uri: application.redirect_uri[0, 100]
          },
          ip_address: ip_address
        )
      end
    end
  end
end
