# frozen_string_literal: true

module Gitlab
  module Checks
    module SecretPushProtection
      class SecretsCheck < ::Gitlab::Checks::BaseBulkChecker
        include ::Gitlab::InternalEventsTracking
        include ::Gitlab::Utils::StrongMemoize
        include ::Gitlab::Loggable

        ERROR_MESSAGES = {
          scan_initialization_error: 'Secret detection scan failed to initialize. %{error_msg}'
        }.freeze

        LOG_MESSAGES = {
          secrets_check: 'Detecting secrets...'
        }.freeze

        def validate!
          run_validation_dark_launch! if should_run_dark_launch?
          run_validation!
        end

        private

        def should_run_dark_launch?
          Feature.enabled?(:secret_detection_enable_spp_for_public_projects, project) &&
            public_project_without_spp?
        end

        # Returns true for public projects that don't have SPP enabled
        def public_project_without_spp?
          project.public? &&
            (!project.licensed_feature_available?(:secret_push_protection) ||
             !project.security_setting&.secret_push_protection_enabled?)
        end

        # Dark launch: Route SPP traffic through SDS for public projects to validate load handling.
        # This sends real production traffic to SDS without affecting the user experience or
        # blocking pushes. Used to test SDS capacity before full rollout.
        # Only runs for public projects that don't have SPP enabled or licensed.
        # See: https://gitlab.com/gitlab-org/gitlab/-/issues/551932
        def run_validation_dark_launch!
          logger.log_timed(LOG_MESSAGES[:secrets_check]) do
            payloads = payload_processor.standardize_payloads
            break unless payloads

            sds_client.send_request_to_sds(payloads, exclusions: exclusions_manager.active_exclusions)
          end
        end

        def run_validation!
          return unless eligibility_checker.should_scan?

          thread = nil

          logger.log_timed(LOG_MESSAGES[:secrets_check]) do
            payloads = payload_processor.standardize_payloads

            thread = Thread.new do
              # This is to help identify the thread in case of a crash
              Thread.current.name = "secrets_check"

              # All the code run in the thread handles exceptions so we can leave these off
              Thread.current.abort_on_exception = false
              Thread.current.report_on_exception = false

              sds_client.send_request_to_sds(payloads, exclusions: exclusions_manager.active_exclusions)
            end

            # Pass payloads to gem for scanning.
            response = ::Gitlab::SecretDetection::Core::Scanner
              .new(rules: ruleset, logger: secret_detection_logger)
              .secrets_scan(
                payloads,
                timeout: logger.time_left,
                exclusions: exclusions_manager.active_exclusions
              )

            # Log audit events for exlusions that were applied.
            audit_logger.log_applied_exclusions_audit_events(response.applied_exclusions)

            response = response_handler.format_response(response)

            # Wait for the thread to complete up until we time out, returns `nil` on timeout
            thread&.join(logger.time_left)

            response
          # TODO: Perhaps have a separate message for each and better logging?
          rescue ::Gitlab::SecretDetection::Core::Ruleset::RulesetParseError,
            ::Gitlab::SecretDetection::Core::Ruleset::RulesetCompilationError => e

            message = format(ERROR_MESSAGES[:scan_initialization_error], { error_msg: e.message })
            secret_detection_logger.error(build_structured_payload(message:))
          ensure
            # clean up the thread
            thread&.exit
          end
        end

        ##############################
        # Helpers

        def ruleset
          ::Gitlab::SecretDetection::Core::Ruleset.new(
            logger: secret_detection_logger
          ).rules
        end
        strong_memoize_attr :ruleset

        ############################
        # Audits and Event Logging
        # Creates audit events and tracks analytics for SPP activity

        def audit_logger
          @audit_logger ||= Gitlab::Checks::SecretPushProtection::AuditLogger.new(
            project: project,
            changes_access: changes_access
          )
        end

        def secret_detection_logger
          @secret_detection_logger ||= ::Gitlab::SecretDetectionLogger.build
        end

        ##############
        # Scan Checks
        # Determines whether SPP scanning should occur

        def eligibility_checker
          @eligibility_checker = Gitlab::Checks::SecretPushProtection::EligibilityChecker.new(
            project: project,
            changes_access: changes_access
          )
        end

        ##############
        # Payload Processor
        # Standardizes, parses, and processes diffs

        def payload_processor
          @payload_processor = Gitlab::Checks::SecretPushProtection::PayloadProcessor.new(
            project: project,
            changes_access: changes_access
          )
        end

        ##############
        # Response Handler
        # Handle the response depending on the status returned

        def response_handler
          @response_handler = Gitlab::Checks::SecretPushProtection::ResponseHandler.new(
            project: project,
            changes_access: changes_access
          )
        end

        ##############
        # Exclusions
        # Manages rule, path, and raw value exclusions

        def exclusions_manager
          @exclusions_manager ||= ::Gitlab::Checks::SecretPushProtection::ExclusionsManager.new(
            project: project,
            changes_access: changes_access
          )
        end

        ##############
        # Secret Detection Service Client
        # Manages communication with the external Secret Detection Service

        def sds_client
          @sds_client = Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient.new(
            project: project
          )
        end
      end
    end
  end
end
