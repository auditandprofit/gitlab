# frozen_string_literal: true

module EE
  module Members
    module Projects
      module CreatorService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        private

        override :can_create_new_member?
        def can_create_new_member?
          super && current_user.can?(:invite_project_members, member.project)
        end
      end
    end
  end
end
