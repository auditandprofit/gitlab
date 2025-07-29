# frozen_string_literal: true

module EE
  module Projects
    module GroupLinks
      module DestroyService
        extend ::Gitlab::Utils::Override
        include ::GitlabSubscriptions::CodeSuggestionsHelper

        override :execute
        def execute(group_link, skip_authorization: false)
          super.tap do |result|
            link = result.payload[:link]

            if link && !link.persisted?
              send_audit_event(link)

              enqueue_refresh_add_on_assignments_woker(link)
            end
          end
        end

        private

        def send_audit_event(group_link)
          return unless current_user

          audit_context = {
            name: 'project_group_link_deleted',
            author: current_user,
            scope: group_link.group,
            target: project,
            target_details: project.full_path,
            message: 'Removed project group link',
            additional_details: {
              remove: 'project_access'
            }
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def enqueue_refresh_add_on_assignments_woker(link)
          namespace = link.project.root_ancestor

          return unless gitlab_com_subscription?

          GitlabSubscriptions::AddOnPurchases::RefreshUserAssignmentsWorker.perform_async(namespace.id)
        end
      end
    end
  end
end
