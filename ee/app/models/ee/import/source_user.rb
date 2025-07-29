# frozen_string_literal: true

module EE
  module Import
    module SourceUser
      extend ::Gitlab::Utils::Override

      override :enterprise_bypass_placeholder_confirmation_allowed?
      def enterprise_bypass_placeholder_confirmation_allowed?
        ::Import::UserMapping::EnterpriseBypassAuthorizer.new(namespace, reassign_to_user, reassigned_by_user).allowed?
      end
    end
  end
end
