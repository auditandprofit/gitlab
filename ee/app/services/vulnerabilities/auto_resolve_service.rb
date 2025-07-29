# frozen_string_literal: true

module Vulnerabilities
  class AutoResolveService
    include Gitlab::Utils::StrongMemoize
    include Gitlab::InternalEventsTracking

    def initialize(project, vulnerability_ids, budget)
      @project = project
      @vulnerability_ids = vulnerability_ids
      @budget = budget
    end

    def execute
      return ServiceResponse.success(payload: { count: 0 }) if policies.blank?

      ensure_bot_user_exists

      unless can_create_state_transitions?
        return error_response(reason: 'Bot user does not have permission to create state transitions')
      end

      resolve_vulnerabilities
      refresh_statistics

      ServiceResponse.success(payload: { count: vulnerabilities_to_resolve.size })
    rescue ActiveRecord::ActiveRecordError => e
      error_response(reason: 'ActiveRecord error', exception: e)
    end

    private

    attr_reader :project, :vulnerability_ids, :budget

    def vulnerability_reads
      Vulnerabilities::Read.by_vulnerabilities(vulnerability_ids).with_states(auto_resolve_states)
    end

    def auto_resolve_states
      ::Enums::Vulnerability.vulnerability_states.except(:resolved, :dismissed).values
    end

    def vulnerabilities_to_resolve
      rules_by_vulnerability.keys.first(budget)
    end

    def rules_by_vulnerability
      vulnerability_reads.index_with do |read|
        rules.find { |rule| rule.match?(read) }
      end.compact
    end
    strong_memoize_attr :rules_by_vulnerability

    def policies
      project
        .vulnerability_management_policies
        .auto_resolve_policies_with_rules
    end

    def rules
      policies
        .flat_map(&:vulnerability_management_policy_rules)
        .select(&:type_no_longer_detected?)
    end
    strong_memoize_attr :rules

    def ensure_bot_user_exists
      ::Security::Orchestration::CreateBotService.new(project, nil, skip_authorization: true).execute
    end

    def resolve_vulnerabilities
      return if vulnerabilities_to_resolve.empty?

      Vulnerability.transaction do
        Vulnerabilities::StateTransition.insert_all!(state_transition_attrs)

        # The caller (Security::Ingestion::MarkAsResolvedService) operates on ALL Vulnerability::Read rows
        # narrowed by scanner type in batches of 1000. If we apply any sort of limit here then this poses a problem:
        # 1. A policy is set to auto-resolve crical SAST vulnerabiliites.
        # 2. In the first 1000 SAST Vulnerability::Read rows there's one critical vulnerability.
        # 3. There's no guarantee that the critical vulnerability is going to be among the first 100 rows

        # Theoretically we could sort them according to severity but this will also not work if you have a policy
        # that auto-resolves Critical and Low SAST vulnerabilities. First 100 will most certainly contain the Critical
        # ones but the Low ones are going to be at the end of the collection
        vulnerabilities_to_update = Vulnerability.id_in(vulnerabilities_to_resolve.map(&:vulnerability_id))

        Vulnerabilities::BulkEsOperationService.new(vulnerabilities_to_update).execute do |vulnerabilities|
          vulnerabilities.update_all(
            state: :resolved,
            auto_resolved: true,
            resolved_by_id: user.id,
            resolved_at: now,
            updated_at: now)
        end
      end

      Note.transaction do
        results = Note.insert_all!(system_note_attrs, returning: %w[id])
        SystemNoteMetadata.insert_all!(note_metadata_attrs(results))
      end

      track_internal_event(
        'autoresolve_vulnerability_in_project_after_pipeline_run_if_policy_is_set',
        project: project,
        additional_properties: {
          value: vulnerabilities_to_resolve.size
        }
      )
    end

    def state_transition_attrs
      vulnerabilities_to_resolve.map do |vulnerability|
        {
          vulnerability_id: vulnerability.id,
          from_state: vulnerability.state,
          to_state: :resolved,
          author_id: user.id,
          comment: comment(vulnerability),
          created_at: now,
          updated_at: now
        }
      end
    end

    def system_note_attrs
      vulnerabilities_to_resolve.map do |vulnerability|
        {
          noteable_type: "Vulnerability",
          noteable_id: vulnerability.id,
          project_id: project.id,
          namespace_id: project.project_namespace_id,
          system: true,
          note: ::SystemNotes::VulnerabilitiesService.formatted_note(
            'changed',
            :resolved,
            nil,
            comment(vulnerability)
          ),
          author_id: user.id,
          created_at: now,
          updated_at: now
        }
      end
    end

    def note_metadata_attrs(results)
      results.map do |row|
        id = row['id']

        {
          note_id: id,
          action: 'vulnerability_resolved',
          created_at: now,
          updated_at: now
        }
      end
    end

    def comment(vulnerability)
      rule = rules_by_vulnerability[vulnerability]
      format(_("Auto-resolved by the vulnerability management policy named '%{policy_name}'"),
        policy_name: rule.security_policy.name)
    end

    def user
      @user ||= project.security_policy_bot
    end

    def refresh_statistics
      Vulnerabilities::Statistics::AdjustmentWorker.perform_async([project.id])
    end

    def can_create_state_transitions?
      Ability.allowed?(user, :create_vulnerability_state_transition, project)
    end

    # We use this for setting the created_at and updated_at timestamps
    # for the various records created by this service.
    # The time is memoized on the first call to this method so all of the
    # created records will have the same timestamps.
    def now
      @now ||= Time.current.utc
    end

    def error_response(reason:, exception: nil)
      ServiceResponse.error(
        message: "Could not resolve vulnerabilities",
        reason: reason,
        payload: { exception: exception }
      )
    end
  end
end
