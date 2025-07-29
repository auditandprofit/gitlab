# frozen_string_literal: true

module Security
  class SyncProjectPolicyWorker
    include ApplicationWorker
    prepend ::Geo::SkipSecondary

    data_consistency :sticky
    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once

    concurrency_limit -> { 200 }

    feature_category :security_policy_management

    SUPPORTED_EVENTS = [
      'Repositories::ProtectedBranchCreatedEvent',
      'Repositories::ProtectedBranchDestroyedEvent',
      'Repositories::DefaultBranchChangedEvent',
      'Projects::ComplianceFrameworkChangedEvent',
      'Security::PolicyResyncEvent'
    ].freeze

    # This is needed to ensure that the worker does not run multiple times for the same security policy
    # when there is an already existing job that handles a different update from policy_chages.
    def self.idempotency_arguments(arguments)
      project_id, security_policy_id, _, _ = arguments

      [project_id, security_policy_id]
    end

    def perform(project_id, security_policy_id, policy_changes = {}, params = {})
      project = Project.find_by_id(project_id)
      security_policy = Security::Policy.find_by_id(security_policy_id)

      return unless project && security_policy

      if params['event'].present?
        handle_event(project, security_policy, params['event'])
      else
        handle_policy_changes(project, security_policy, policy_changes)
      end
    end

    def handle_policy_changes(project, security_policy, policy_changes)
      Security::SecurityOrchestrationPolicies::SyncProjectService.new(
        security_policy: security_policy,
        project: project,
        policy_changes: policy_changes.deep_symbolize_keys
      ).execute
    end

    def handle_event(project, security_policy, event)
      event_type = event['event_type']
      event_data = event['data']

      if SUPPORTED_EVENTS.exclude?(event_type) || event_data.blank?
        Gitlab::AppJsonLogger.error(
          message: 'Invalid event type or data',
          event_type: event_type,
          event_data: event_data,
          project_id: project.id,
          security_policy_id: security_policy.id
        )
        return
      end

      Security::SecurityOrchestrationPolicies::SyncPolicyEventService.new(
        project: project,
        security_policy: security_policy,
        event: event_type.constantize.new(data: event_data)
      ).execute
    end
  end
end
