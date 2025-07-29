# frozen_string_literal: true

module Gitlab
  module Checks
    module SecretPushProtection
      class AuditLogger < ::Gitlab::Checks::SecretPushProtection::Base
        include ::Gitlab::InternalEventsTracking

        def initialize(project:, changes_access:)
          super
          @user = changes_access.user_access.user
        end

        def log_skip_secret_push_protection(skip_method)
          branch_name = changes_access.single_change_accesses.first.branch_name
          message = "#{_('Secret push protection skipped via')} #{skip_method} on branch #{branch_name}"
          audit_context = {
            name: 'skip_secret_push_protection',
            author: @user,
            target: project,
            scope: project,
            message: message,
            target_details: generate_target_details
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def log_exclusion_audit_event(exclusion)
          audit_context = {
            name: 'project_security_exclusion_applied',
            author: @user,
            target: exclusion,
            scope: project,
            message: "An exclusion of type (#{exclusion.type}) with value (#{exclusion.value}) was " \
              "applied in Secret push protection"
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def log_applied_exclusions_audit_events(applied_exclusions)
          applied_exclusions.each do |exclusion|
            project_security_exclusion = get_project_security_exclusion_from_sds_exclusion(exclusion)
            log_exclusion_audit_event(project_security_exclusion) unless project_security_exclusion.nil?
          end
        end

        def track_spp_skipped(skip_method)
          track_internal_event(
            'skip_secret_push_protection',
            user: @user,
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: skip_method
            }
          )
        end

        def track_secret_found(secret_type)
          track_internal_event(
            'detect_secret_type_on_push',
            user: @user,
            project: project,
            namespace: project.namespace,
            additional_properties: {
              label: secret_type
            }
          )
        end

        private

        def generate_target_details
          changes = changes_access.changes
          old_rev = changes.first&.dig(:oldrev)
          new_rev = changes.last&.dig(:newrev)

          return project.name if old_rev.nil? || new_rev.nil?

          ::Gitlab::Utils.append_path(
            ::Gitlab::Routing.url_helpers.root_url,
            ::Gitlab::Routing.url_helpers.project_compare_path(project, from: old_rev, to: new_rev)
          )
        end

        def get_project_security_exclusion_from_sds_exclusion(exclusion)
          return exclusion if exclusion.is_a?(::Security::ProjectSecurityExclusion)

          project.security_exclusions.where(value: exclusion.value).first # rubocop:disable CodeReuse/ActiveRecord -- Need to be able to link GRPC::Exclusion to ProjectSecurityExclusion
        end
      end
    end
  end
end
