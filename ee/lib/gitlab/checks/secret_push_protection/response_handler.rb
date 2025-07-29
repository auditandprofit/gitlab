# frozen_string_literal: true

module Gitlab
  module Checks
    module SecretPushProtection
      class ResponseHandler < ::Gitlab::Checks::SecretPushProtection::Base
        ERROR_MESSAGES = {
          failed_to_scan_regex_error: "\n    - Failed to scan blob(id: %{payload_id}) due to regex error.",
          blob_timed_out_error: "\n    - Scanning blob(id: %{payload_id}) timed out.",
          scan_timeout_error: 'Secret detection scan timed out.',
          invalid_input_error: 'Secret detection scan failed due to invalid input.',
          invalid_scan_status_code_error: 'Invalid secret detection scan status, check passed.',
          too_many_tree_entries_error: 'Too many tree entries exist for commit(sha: %{sha}).'
        }.freeze

        LOG_MESSAGES = {
          secrets_not_found: 'Secret detection scan completed with no findings.',
          skip_secret_detection: "\n\nTo skip secret push protection, add the following Git push option " \
            "to your push command: `-o secret_push_protection.skip_all`",
          found_secrets: "\nPUSH BLOCKED: Secrets detected in code changes",
          found_secrets_post_message: "\n\nTo push your changes you must remove the identified secrets.",
          found_secrets_docs_link: "\nFor guidance, see %{path}",
          found_secrets_with_errors: 'Secret detection scan completed with one or more findings ' \
            'but some errors occured during the scan.',
          finding_message_occurrence_header: "\n\nSecret push protection " \
            "found the following secrets in commit: %{sha}",
          finding_message_occurrence_path: "\n-- %{path}:",
          finding_message_occurrence_line: "%{line_number} | %{description}",
          finding_message: "\n\nSecret leaked in blob: %{payload_id}" \
            "\n  -- line:%{line_number} | %{description}",
          found_secrets_footer: "\n--------------------------------------------------\n\n",
          invalid_log_level: "Unknown log level %{log_level} for message: %{message}"
        }.freeze

        def format_response(response)
          # Try to retrieve file path and commit sha for the diffs found.
          if response.status == ::Gitlab::SecretDetection::Core::Status::FOUND ||
              response.status == ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS

            results = transform_findings(response)

            # If there is no findings in `response.results`, that means all findings
            # were excluded in `transform_findings`, so we set status to no secrets found.
            if response.results.empty?
              response = ::Gitlab::SecretDetection::Core::Response.new(
                status: ::Gitlab::SecretDetection::Core::Status::NOT_FOUND,
                results: []
              )
            end
          end

          case response.status
          when ::Gitlab::SecretDetection::Core::Status::NOT_FOUND
            # No secrets found, we log and skip the check.
            secret_detection_logger.info(build_structured_payload(message: LOG_MESSAGES[:secrets_not_found]))
          when ::Gitlab::SecretDetection::Core::Status::FOUND
            # One or more secrets found, generate message with findings and fail check.
            message = build_secrets_found_message(results)

            secret_detection_logger.info(
              build_structured_payload(message: LOG_MESSAGES[:found_secrets])
            )

            raise ::Gitlab::GitAccess::ForbiddenError, message
          when ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS
            # One or more secrets found, but with scan errors, so we
            # generate a message with findings and errors, and fail the check.
            message = build_secrets_found_message(results, with_errors: true)

            secret_detection_logger.info(
              build_structured_payload(message: LOG_MESSAGES[:found_secrets_with_errors])
            )

            raise ::Gitlab::GitAccess::ForbiddenError, message
          when ::Gitlab::SecretDetection::Core::Status::SCAN_TIMEOUT
            # Entire scan timed out, we log and skip the check for now.
            secret_detection_logger.error(
              build_structured_payload(message: ERROR_MESSAGES[:scan_timeout_error])
            )
          when ::Gitlab::SecretDetection::Core::Status::INPUT_ERROR
            # Scan failed due to invalid input. We skip the check because of an input error
            # which could be due to not having anything to scan.
            secret_detection_logger.error(
              build_structured_payload(message: ERROR_MESSAGES[:invalid_input_error])
            )
          else
            # Invalid status returned by the scanning service/gem, we don't
            # know how to handle that, so nothing happens and we skip the check.
            secret_detection_logger.error(
              build_structured_payload(message: ERROR_MESSAGES[:invalid_scan_status_code_error])
            )
          end
        end

        private

        def commits
          @commit ||= changes_access.commits.map(&:valid_full_sha)
        end

        # rubocop:disable Metrics/CyclomaticComplexity -- Not easy to move complexity away into other methods,
        def transform_findings(response)
          # Let's group the findings by the blob id.
          findings_by_blobs = response.results.group_by(&:payload_id)

          # We create an empty hash for the structure we'll create later as we pull out tree entries.
          findings_by_commits = {}

          # Let's create a set to store ids of blobs found in tree entries.
          blobs_found_with_tree_entries = Set.new

          # Scanning had found secrets, let's try to look up their file path and commit id. This can be done
          # by using `GetTreeEntries()` RPC, and cross examining blobs with ones where secrets where found.
          commits.each do |revision|
            # We could try to handle pagination, but it is likely to timeout way earlier given the
            # huge default limit (100000) of entries, so we log an error if we get too many results.
            entries, cursor = ::Gitlab::Git::Tree.tree_entries(
              repository: project.repository,
              sha: revision,
              recursive: true,
              rescue_not_found: false
            )

            # TODO: Handle pagination in the upcoming iterations
            # We don't raise because we could still provide a hint to the user
            # about the detected secrets even without a commit sha/file path information.
            unless cursor.next_cursor.empty?
              secret_detection_logger.error(
                build_structured_payload(
                  message: format(ERROR_MESSAGES[:too_many_tree_entries_error], { sha: revision })
                )
              )
            end

            # Let's grab the `commit_id` and the `path` for that entry, we use the blob id as key.
            entries.each do |entry|
              # Skip any entry that isn't a blob.
              next if entry.type != :blob

              # Skip if the blob doesn't have any findings.
              next unless findings_by_blobs[entry.id].present?

              # Skip a tree entry if it's excluded from scanning by the user based on its file
              # path. We unfortunately have to do this after scanning is done because we only get
              # file paths when calling `GetTreeEntries()` RPC and not earlier. When diff scanning
              # is available, we will likely be able move this check to the gem/secret detection service
              # since paths will be available pre-scanning.
              if exclusions_manager.matches_excluded_path?(entry.path)
                response.results.delete_if { |finding| finding.payload_id == entry.id }

                findings_by_blobs.delete(entry.id)

                next
              end

              new_entry = findings_by_blobs[entry.id].each_with_object({}) do |finding, hash|
                hash[entry.commit_id] ||= {}
                hash[entry.commit_id][entry.path] ||= []
                hash[entry.commit_id][entry.path] << finding
              end

              # Put findings with tree entries inside `findings_by_commits` hash.
              findings_by_commits.merge!(new_entry) do |_commit_sha, existing_findings, new_findings|
                existing_findings.merge!(new_findings)
              end

              # Mark as found with tree entry already.
              blobs_found_with_tree_entries << entry.id
            end
          end

          # Remove blobs that has already been found in a tree entry.
          findings_by_blobs.delete_if { |payload_id, _| blobs_found_with_tree_entries.include?(payload_id) }

          # Return the findings as a hash sorted by commits and blobs (minus ones already found).
          {
            commits: findings_by_commits,
            blobs: findings_by_blobs
          }
        end
        # rubocop:enable Metrics/CyclomaticComplexity

        def build_secrets_found_message(results, with_errors: false)
          message = with_errors ? LOG_MESSAGES[:found_secrets_with_errors] : LOG_MESSAGES[:found_secrets]

          results[:commits].each do |sha, paths|
            message += format(LOG_MESSAGES[:finding_message_occurrence_header], { sha: sha })

            paths.each do |path, findings|
              findings.each do |finding|
                message += format(LOG_MESSAGES[:finding_message_occurrence_path], { path: path })
                message += build_finding_message(finding, :commit)
              end
            end
          end

          results[:blobs].values.compact.each do |findings|
            findings.each do |finding|
              message += build_finding_message(finding, :blob)
            end
          end

          message += LOG_MESSAGES[:found_secrets_post_message]

          docs_url = Rails.application.routes.url_helpers.help_page_url(
            'user/application_security/secret_detection/secret_push_protection/_index.md',
            anchor: 'resolve-a-blocked-push'
          )

          message += format(
            LOG_MESSAGES[:found_secrets_docs_link],
            { path: docs_url }
          )

          message += LOG_MESSAGES[:skip_secret_detection]
          message += LOG_MESSAGES[:found_secrets_footer]
          message
        end

        def build_finding_message(finding, type)
          case finding.status
          when ::Gitlab::SecretDetection::Core::Status::FOUND
            # Track the secret finding in audit logs.
            audit_logger.track_secret_found(finding.description)

            if type == :commit
              build_commit_finding_message(finding)
            elsif type == :blob
              build_blob_finding_message(finding)
            end
          when ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
            format(ERROR_MESSAGES[:failed_to_scan_regex_error], { payload_id: finding.payload_id })
          when ::Gitlab::SecretDetection::Core::Status::PAYLOAD_TIMEOUT
            format(ERROR_MESSAGES[:blob_timed_out_error], { payload_id: finding.payload_id })
          end
        end

        def build_commit_finding_message(finding)
          format(
            LOG_MESSAGES[:finding_message_occurrence_line],
            {
              line_number: finding.line_number,
              description: finding.description
            }
          )
        end

        def build_blob_finding_message(finding)
          format(LOG_MESSAGES[:finding_message], finding.to_h)
        end

        def exclusions_manager
          @exclusions_manager ||= ::Gitlab::Checks::SecretPushProtection::ExclusionsManager.new(
            project: project,
            changes_access: changes_access
          )
        end
      end
    end
  end
end
