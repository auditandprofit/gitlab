# frozen_string_literal: true

module Repositories
  module PullMirrors
    class UpdateService < ::BaseService
      def execute
        return ServiceResponse.error(message: _('Access Denied')) unless allowed?

        if update_mirror
          project.import_state.force_import_job! if project.mirror?

          ServiceResponse.success(payload: { project: project })
        else
          ServiceResponse.error(message: project.errors)
        end
      end

      private

      def update_mirror
        project.assign_attributes(allowed_attributes.merge(mirror_user_id: current_user.id))

        update_project_import_relations

        project.save

        # It's possible that import state is not created, when user doesn't set an import_url
        # Treat it as an error
        project.errors.add(:url, 'is missing') if mirror_import_state_missing?
        project.errors.none?
      end

      def update_project_import_relations
        if mirror_disabled?
          # Import data includes credentials that should be removed, when mirror is disabled.
          project.remove_import_data
        else
          project.build_or_assign_import_data(credentials: params[:credentials])
        end

        project.import_state&.assign_attributes(last_error: nil)
      end

      def mirror_disabled?
        allowed_attributes[:mirror] == false
      end

      def mirror_import_state_missing?
        project.import_state.blank?
      end

      def allowed_attributes
        @allowed_attributes ||= ::Repositories::PullMirrors::Attributes.new(params).allowed
      end

      def allowed?
        Ability.allowed?(current_user, :admin_remote_mirror, project)
      end
    end
  end
end
