# frozen_string_literal: true
module Quality
  module Seeders
    class Vulnerabilities
      attr_reader :project

      def initialize(project)
        @project = project
      end

      def seed!
        if author.nil?
          print 'Skipping this project because it has no users'
          return
        end

        30.times do |rank|
          primary_identifier = create_identifier(rank)
          finding = create_finding(rank, primary_identifier)
          vulnerability = create_vulnerability(finding: finding)

          # The primary identifier is already associated via the finding creation
          # Only add additional identifier if rank % 3 == 0 and it's different from primary
          if rank % 3 == 0
            secondary_identifier = create_identifier(rank + 1000) # Ensure it's different
            finding.identifiers << secondary_identifier unless finding.identifiers.include?(secondary_identifier)
          end

          finding.update!(vulnerability_id: vulnerability.id)

          create_vulnerability_read(vulnerability, finding)

          case rank % 3
          when 0
            create_feedback(finding, 'dismissal')
          when 1
            create_feedback(finding, 'issue', vulnerability: vulnerability)
          end

          print '.'
        end
      end

      private

      def create_vulnerability(finding:)
        state_symbol = ::Vulnerability.states.keys.sample.to_sym
        vulnerability = build_vulnerability(state_symbol)
        vulnerability.finding_id = finding.id

        case state_symbol
        when :resolved
          vulnerability.resolved_by = author
        when :dismissed
          vulnerability.dismissed_by = author
        end

        vulnerability.tap(&:save!)
      end

      def build_vulnerability(state_symbol)
        FactoryBot.build(
          :vulnerability,
          state_symbol,
          project: project,
          author: author,
          title: 'Cypher with no integrity',
          severity: random_severity_level,
          report_type: random_report_type
        )
      end

      def create_finding(rank, primary_identifier)
        scanner = find_or_create_scanner

        # Generate a unique location fingerprint for each finding
        unique_fingerprint = "#{random_fingerprint}_#{rank}_#{Time.current.to_i}"

        FactoryBot.create(
          :vulnerabilities_finding,
          :with_pipeline,
          project: project,
          scanner: scanner,
          severity: random_severity_level,
          primary_identifier: primary_identifier,
          location_fingerprint: unique_fingerprint,
          raw_metadata: Gitlab::Json.dump(metadata(rank))
        )
      end

      def find_or_create_scanner
        # Reuse scanner if it exists to avoid uniqueness violations
        # rubocop:disable CodeReuse/ActiveRecord
        @scanner ||= ::Vulnerabilities::Scanner.find_or_create_by!(
          project: project,
          external_id: 'security-scanner'
        ) do |scanner|
          scanner.name = 'Security Scanner'
        end
        # rubocop:enable CodeReuse/ActiveRecord
      end

      def create_identifier(rank)
        # Try to find existing identifier first
        external_id = "SECURITY_#{rank}"
        # rubocop:disable CodeReuse/ActiveRecord
        existing_identifier = ::Vulnerabilities::Identifier.find_by(
          project: project,
          external_type: "SECURITY_ID",
          external_id: external_id
        )
        # rubocop:enable CodeReuse/ActiveRecord

        return existing_identifier if existing_identifier

        # If not found, create with unique ID to avoid conflicts
        timestamp = Time.current.to_i
        unique_id = "#{rank}_#{timestamp}_#{SecureRandom.hex(4)}"

        FactoryBot.create(
          :vulnerabilities_identifier,
          external_type: "SECURITY_ID",
          external_id: "SECURITY_#{unique_id}",
          fingerprint: random_fingerprint,
          name: "SECURITY_IDENTIFIER #{rank}",
          url: "https://security.example.com/#{unique_id}",
          project: project
        )
      end

      def create_feedback(finding, type, vulnerability: nil)
        issue = create_issue("Dismiss #{finding.name}") if type == 'issue'
        create_vulnerability_issue_link(vulnerability, issue) if vulnerability && issue

        FactoryBot.create(
          :vulnerability_feedback,
          feedback_type: type,
          project: project,
          author: author,
          issue: issue,
          pipeline: pipeline
        )
      end

      def create_issue(title)
        FactoryBot.create(
          :issue,
          project: project,
          author: author,
          title: title
        )
      end

      def create_vulnerability_issue_link(vulnerability, issue)
        FactoryBot.create(
          :vulnerabilities_issue_link,
          :created,
          vulnerability: vulnerability,
          issue: issue
        )
      end

      def create_vulnerability_read(vulnerability, finding)
        # Skip if vulnerability_read already exists
        # rubocop:disable CodeReuse/ActiveRecord
        return if ::Vulnerabilities::Read.exists?(vulnerability_id: vulnerability.id)

        # rubocop:enable CodeReuse/ActiveRecord

        ::Vulnerabilities::Read.create!(
          vulnerability_id: vulnerability.id,
          project_id: vulnerability.project_id,
          scanner_id: finding.scanner_id,
          report_type: vulnerability.report_type,
          severity: vulnerability.severity,
          state: vulnerability.state,
          resolved_on_default_branch: vulnerability.resolved_on_default_branch,
          uuid: finding.uuid,
          location_image: vulnerability.location&.dig('image'),
          cluster_agent_id: vulnerability.location&.dig('kubernetes_resource', 'agent_id'),
          casted_cluster_agent_id: vulnerability.location&.dig('kubernetes_resource', 'agent_id')&.to_i,
          has_issues: vulnerability.issue_links.any?,
          has_merge_request: vulnerability.merge_request_links.any?,
          traversal_ids: vulnerability.project.namespace.traversal_ids,
          archived: vulnerability.project.archived,
          identifier_names: finding.identifiers.map(&:name),
          owasp_top_10: -1,
          has_vulnerability_resolution: false
        )
      rescue ActiveRecord::RecordInvalid => e
        print "\nFailed to create vulnerability_read for vulnerability #{vulnerability.id}: #{e.message}\n"
      end

      def random_severity_level
        ::Enums::Vulnerability.severity_levels.keys.sample
      end

      def random_report_type
        ::Enums::Vulnerability.report_types.keys.sample
      end

      def metadata(line)
        {
          description: "The cipher does not provide data integrity update 1",
          solution: "GCM mode introduces an HMAC into the resulting encrypted data, providing integrity of the result.",
          location: {
            file: "maven/src/main/java//App.java",
            start_line: line,
            end_line: line,
            class: "com.gitlab..App",
            method: "insecureCypher"
          },
          links: [
            {
              name: "Cipher does not check for integrity first?",
              url: "https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first"
            }
          ]
        }
      end

      def random_fingerprint
        SecureRandom.hex(20)
      end

      def pipeline
        @pipeline ||= project.ci_pipelines.where(ref: project.default_branch).last # rubocop:disable CodeReuse/ActiveRecord
      end

      def author
        @author ||= project.users.first
      end
    end
  end
end
