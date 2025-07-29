# frozen_string_literal: true

module Vulnerabilities
  module Archival
    module Export
      module Exporters
        class CsvService
          CSV_DELIMITER = '; '

          def initialize(iterator)
            @iterator = iterator
          end

          def generate(&block)
            csv_builder.render(&block)
          end

          private

          attr_reader :iterator

          def csv_builder
            @csv_builder ||= CsvBuilder.new(iterator, mapping, replace_newlines: true)
          end

          def mapping
            {
              'Tool' => 'report_type',
              'Scanner Name' => 'scanner',
              'Status' => 'state',
              'Vulnerability' => 'title',
              'Details' => 'description',
              'Severity' => 'severity',
              'CVE' => 'cve_value',
              'CWE' => 'cwe_value',
              'Other Identifiers' => method(:identifier_formatter),
              'Dismissed At' => 'dismissed_at',
              'Dismissed By' => 'dismissed_by',
              'Confirmed At' => 'confirmed_at',
              'Confirmed By' => 'confirmed_by',
              'Resolved At' => 'resolved_at',
              'Resolved By' => 'resolved_by',
              'Detected At' => 'created_at',
              'Location' => 'location',
              'Issues' => 'related_issues',
              'Merge Requests' => 'related_mrs',
              'Activity' => 'resolved_on_default_branch',
              'Comments' => 'notes_summary',
              'Full Path' => 'full_path',
              'CVSS Vectors' => method(:cvss_formatter),
              'Dismissal Reason' => method(:dismissal_formatter)
            }
          end

          def identifier_formatter(data)
            data['other_identifiers'].to_csv(col_sep: CSV_DELIMITER, row_sep: '')
          end

          def dismissal_formatter(data)
            data['dismissal_reason']&.humanize
          end

          def cvss_formatter(data)
            data['cvss'].map { |cvss| "#{cvss['vendor']}=#{cvss['vector']}" }
                        .to_csv(col_sep: CSV_DELIMITER, row_sep: '')
          end
        end
      end
    end
  end
end
