# frozen_string_literal: true

module MemberRoles
  class CreateService < ::Authz::CustomRoles::BaseService
    def execute
      return authorized_error unless allowed?

      @role = build_role
      if role.save
        log_audit_event(action: :created)

        success
      else

        error
      end
    end

    private

    def build_role
      MemberRole.new(params.merge(namespace: namespace))
    end

    def allowed?
      subject = namespace || :global
      can?(current_user, :admin_member_role, subject)
    end
  end
end
