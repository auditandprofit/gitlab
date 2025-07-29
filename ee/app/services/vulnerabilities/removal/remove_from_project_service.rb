# frozen_string_literal: true

module Vulnerabilities
  module Removal
    # This class is responsible for removing the vulnerability records
    # associated with the given project.
    #
    # We are not deleting the `scanner` records because they are associated
    # with the `security_findings` records and deleting them scan cause
    # cascading delete on millions of `security_findings` records.
    class RemoveFromProjectService
      class BatchRemoval
        TASKS_SCOPED_TO_FINDINGS = [
          Tasks::DeleteFindingEvidences,
          Tasks::DeleteFindingFlags,
          Tasks::DeleteFindingIdentifiers,
          Tasks::DeleteFindingLinks,
          Tasks::DeleteFindingRemediations,
          Tasks::DeleteFindingSignatures
        ].freeze

        TASKS_SCOPED_TO_VULNERABILITIES = [
          Tasks::DeleteVulnerabilityExternalIssueLinks,
          Tasks::DeleteVulnerabilityIssueLinks,
          Tasks::DeleteVulnerabilityMergeRequestLinks,
          Tasks::DeleteVulnerabilityReads,
          Tasks::DeleteVulnerabilityStateTransitions,
          Tasks::DeleteVulnerabilityUserMentions
        ].freeze

        def initialize(project, batch, update_counts:)
          @project = project
          @batch = batch
          @update_counts = update_counts
        end

        def execute
          return false if batch_size == 0

          transaction_status = Vulnerability.transaction do
            delete_resources_by_findings
            delete_resources_by_vulnerabilities
            delete_vulnerabilities
            delete_findings

            update_project_vulnerabilities_count if update_counts

            true
          end

          sync_elasticsearch if transaction_status

          true
        end

        private

        attr_reader :project, :batch, :update_counts

        def delete_resources_by_findings
          TASKS_SCOPED_TO_FINDINGS.each { |task| task.new(finding_ids).execute }
        end

        def delete_resources_by_vulnerabilities
          TASKS_SCOPED_TO_VULNERABILITIES.each { |task| task.new(vulnerability_ids).execute }
        end

        def delete_vulnerabilities
          Vulnerability.id_in(vulnerability_ids).delete_all
        end

        def delete_findings
          Vulnerabilities::Finding.id_in(finding_ids).delete_all
        end

        def update_project_vulnerabilities_count
          project.security_statistics.decrease_vulnerability_counter!(batch_size)
        end

        def batch_size
          vulnerability_ids.length
        end

        def vulnerability_ids
          @vulnerability_ids ||= batch_attributes.map(&:first)
        end

        def finding_ids
          @finding_ids ||= batch_attributes.map(&:second)
        end

        def batch_attributes
          @batch_attributes ||= batch.pluck(:id, :finding_id) # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- This is a very specific usage
        end

        def sync_elasticsearch
          vulnerabilities_to_delete = Vulnerability.id_in(vulnerability_ids)

          Vulnerabilities::BulkEsOperationService.new(vulnerabilities_to_delete).execute(&:itself)
        end
      end

      BATCH_SIZE = 100

      def initialize(project, params)
        @project = project
        @resolved_on_default_branch = params[:resolved_on_default_branch]
      end

      def execute
        delete_vulnerabilities_on_default_branch
        delete_vulnerabilities_not_present_on_default_branch
        update_vulnerability_statistics
        delete_feedback_records
        delete_historical_statistics
        reset_has_vulnerabilities
      end

      private

      attr_reader :project, :resolved_on_default_branch

      # Vulnerabilities with `present_on_default_branch` attribute as `true` are associated
      # with `vulnerability_reads`, therefore, iterating over `vulnerability_reads` table
      # is fine.
      def delete_vulnerabilities_on_default_branch
        loop do
          vulnerability_ids = vulnerability_reads.limit(BATCH_SIZE).pluck_primary_key
          vulnerabilities = Vulnerability.id_in(vulnerability_ids)
          batch_removal = BatchRemoval.new(project, vulnerabilities, update_counts: true)

          break unless batch_removal.execute
        end
      end

      # This makes sure that we delete vulnerabilities that are not `present_on_default_branch`.
      def delete_vulnerabilities_not_present_on_default_branch
        return unless full_cleanup?

        loop do
          batch = vulnerabilities.limit(BATCH_SIZE)
          batch_removal = BatchRemoval.new(project, batch, update_counts: false)

          break unless batch_removal.execute
        end
      end

      def vulnerability_reads
        return Vulnerabilities::Read.by_projects(project) if full_cleanup?

        Vulnerabilities::Read.by_projects(project).with_resolution(resolved_on_default_branch)
      end

      def vulnerabilities
        Vulnerability.with_project(project)
      end

      def update_vulnerability_statistics
        Vulnerabilities::Statistics::AdjustmentWorker.perform_async([project.id])
      end

      # Do we really need to delete these records? The feedback model has already been
      # deprecated and the model will be removed soon.
      def delete_feedback_records
        return unless full_cleanup?

        loop { break if project.vulnerability_feedback.limit(BATCH_SIZE).delete_all == 0 }
      end

      def delete_historical_statistics
        return unless full_cleanup?

        loop { break if project.vulnerability_historical_statistics.limit(BATCH_SIZE).delete_all == 0 }
      end

      def full_cleanup?
        resolved_on_default_branch.nil?
      end

      def reset_has_vulnerabilities
        project.project_setting.update!(has_vulnerabilities: vulnerabilities.exists?)
      end
    end
  end
end
