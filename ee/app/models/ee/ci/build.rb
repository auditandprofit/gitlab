# frozen_string_literal: true

module EE
  module Ci
    # Build EE mixin
    #
    # This module is intended to encapsulate EE-specific model logic
    # and be included in the `Build` model
    module Build
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      VALIDATE_SCHEMA_VARIABLE_NAME = 'VALIDATE_SCHEMA'
      LICENSED_PARSER_FEATURES = {
        sast: :sast,
        secret_detection: :secret_detection,
        dependency_scanning: :dependency_scanning,
        container_scanning: :container_scanning,
        cluster_image_scanning: :cluster_image_scanning,
        dast: :dast,
        coverage_fuzzing: :coverage_fuzzing,
        api_fuzzing: :api_fuzzing,
        cyclonedx: :cyclonedx
      }.with_indifferent_access.freeze

      EE_RUNNER_FEATURES = {
        vault_secrets: ->(build) { build.ci_secrets_management_available? && build.secrets? }
      }.freeze

      prepended do
        include UsageStatistics
        include FromUnion
        include ::Ai::Model

        has_many :security_scans, class_name: 'Security::Scan', foreign_key: :build_id

        has_one :dast_site_profiles_build, class_name: 'Dast::SiteProfilesBuild', foreign_key: :ci_build_id
        has_one :dast_site_profile, class_name: 'DastSiteProfile', through: :dast_site_profiles_build, disable_joins: true

        has_one :dast_scanner_profiles_build, class_name: 'Dast::ScannerProfilesBuild', foreign_key: :ci_build_id
        has_one :dast_scanner_profile, class_name: 'DastScannerProfile', through: :dast_scanner_profiles_build, disable_joins: true

        after_commit :track_ci_secrets_management_usage, on: :create
        delegate :service_specification, to: :runner_session, allow_nil: true
        delegate :secrets_provider?, to: :secrets_integration

        scope :license_scan, -> { joins(:job_artifacts).merge(::Ci::JobArtifact.of_report_type(:license_scanning)) }
        scope :with_reports_of_type, ->(report_type) do
          # EE::Enums::Ci::JobArtifact::EE_REPORT_FILE_TYPES has a key
          # of 'dependency_list' which maps to
          # 'dependency_scanning'. Pretty much everywhere else in the
          # codebase we use the naming convention of {report}_scanning
          report_type = report_type.to_sym.then { |r| r == :dependency_scanning ? :dependency_list : r }

          joins(:job_artifacts).merge(::Ci::JobArtifact.of_report_type(report_type.to_sym))
        end
        scope :sbom_generation, -> { joins(:job_artifacts).merge(::Ci::JobArtifact.of_report_type(:sbom)) }
        scope :max_build_id_by, ->(build_name, ref, project_path) do
          select("max(#{quoted_table_name}.id) as id")
            .by_name(build_name)
            .for_ref(ref)
            .for_project_paths(project_path)
        end

        scope :recently_failed_on_instance_runner, ->(failure_reason) do
          merge(::Ci::InstanceRunnerFailedJobs.recent_jobs(failure_reason: failure_reason))
        end

        state_machine :status do
          after_transition any => [:success, :failed, :canceled] do |build|
            build.run_after_commit do
              ::Ci::Minutes::UpdateBuildMinutesService.new(build.project, nil).execute(build)
            end
          end
        end
      end

      class_methods do
        extend ::Gitlab::Utils::Override

        override :clone_accessors
        def clone_accessors
          (super + %i[secrets]).freeze
        end
      end

      override :variables
      def variables
        strong_memoize(:variables) do
          super.tap do |collection|
            collection
              .concat(dast_configuration_variables)
              .concat(google_artifact_registry_variables)
          end
        end
      end

      override :job_jwt_variables
      def job_jwt_variables
        super.concat(identity_variables)
      end

      def cost_factor_enabled?
        runner&.cost_factor_enabled?(project)
      end

      def has_artifact?(name)
        options.dig(:artifacts, :paths)&.include?(name) &&
          artifacts_metadata?
      end

      def has_security_reports?
        job_artifacts.security_reports.any?
      end

      def collect_security_reports!(security_reports, report_types: ::EE::Enums::Ci::JobArtifact.security_report_file_types)
        each_report(report_types) do |file_type, blob, report_artifact|
          security_reports.get_report(file_type, report_artifact).tap do |security_report|
            next unless project.feature_available?(LICENSED_PARSER_FEATURES.fetch(file_type))

            parse_security_artifact_blob(security_report, blob)
          rescue StandardError
            security_report.add_error('ParsingError')
          end
        end
      end

      def unmerged_security_reports
        security_reports = ::Gitlab::Ci::Reports::Security::Reports.new(pipeline)

        each_report(::EE::Enums::Ci::JobArtifact.security_report_file_types) do |file_type, blob, report_artifact|
          report = security_reports.get_report(file_type, report_artifact)
          parse_raw_security_artifact_blob(report, blob)
        end

        security_reports
      end

      def collect_license_scanning_reports!(license_scanning_report)
        return license_scanning_report unless project.feature_available?(:license_scanning)

        each_report(::Ci::JobArtifact.file_types_for_report(:license_scanning)) do |file_type, blob|
          ::Gitlab::Ci::Parsers.fabricate!(file_type).parse!(blob, license_scanning_report)
        end

        license_scanning_report
      end

      def collect_metrics_reports!(metrics_report)
        each_report(::Ci::JobArtifact.file_types_for_report(:metrics)) do |file_type, blob|
          next unless project.feature_available?(:metrics_reports)

          ::Gitlab::Ci::Parsers.fabricate!(file_type).parse!(blob, metrics_report)
        end

        metrics_report
      end

      def collect_requirements_reports!(requirements_report, legacy: false)
        return requirements_report unless project.feature_available?(:requirements)

        artifact_file = legacy ? :requirements : :requirements_v2

        each_report(::Ci::JobArtifact.file_types_for_report(artifact_file)) do |file_type, blob, report_artifact|
          ::Gitlab::Ci::Parsers.fabricate!(file_type).parse!(blob, requirements_report)
        end

        requirements_report
      end

      def collect_sbom_reports!(sbom_reports_list)
        each_report(::Ci::JobArtifact.file_types_for_report(:sbom)) do |file_type, blob|
          report = ::Gitlab::Ci::Reports::Sbom::Report.new
          ::Gitlab::Ci::Parsers.fabricate!(file_type).parse!(blob, report)
          sbom_reports_list.add_report(report)
        end
      end

      def ci_secrets_management_available?
        return false unless project

        project.feature_available?(:ci_secrets_management)
      end

      override :runner_required_feature_names
      def runner_required_feature_names
        super + ee_runner_required_feature_names
      end

      def secrets_integration
        ::Ci::Secrets::Integration.new(variables: variables_encompassing_secrets_configs, project: project)
      end

      def playable?
        super && !waiting_for_deployment_approval?
      end

      def pages
        return {} unless pages_generator?

        super.merge(expand_pages_variables)
      end
      strong_memoize_attr :pages

      private

      def expand_pages_variables
        pages_config
          .slice(:path_prefix, :expire_in)
          .select { |_, v| v.present? }
          .transform_values { |v| expand_variable(v) }
      end

      def variables_hash
        @variables_hash ||= variables.to_h do |variable|
          [variable[:key], variable[:value]]
        end
      end

      def dast_configuration_variables
        ::Gitlab::Ci::Variables::Collection.new.tap do |collection|
          break collection unless (dast_configuration = options[:dast_configuration])

          if (site_profile = dast_configuration[:site_profile] && dast_site_profile)
            collection.concat(dast_site_profile.ci_variables)
            collection.concat(dast_site_profile.secret_ci_variables(user))
          end

          if dast_configuration[:scanner_profile] && dast_scanner_profile
            collection.concat(dast_scanner_profile.ci_variables(dast_site_profile: site_profile))
          end
        end
      end

      def parse_security_artifact_blob(security_report, blob)
        report_clone = security_report.clone_as_blank
        report_clone.pipeline = pipeline # We need to set the pipeline for child pipelines
        parse_raw_security_artifact_blob(report_clone, blob)
        security_report.merge!(report_clone)
      end

      def parse_raw_security_artifact_blob(security_report, blob)
        signatures_enabled = project.licensed_feature_available?(:vulnerability_finding_signatures)
        ::Gitlab::Ci::Parsers.fabricate!(security_report.type, blob, security_report, signatures_enabled: signatures_enabled).parse!
      end

      def ee_runner_required_feature_names
        strong_memoize(:ee_runner_required_feature_names) do
          EE_RUNNER_FEATURES.select do |feature, method|
            method.call(self)
          end.keys
        end
      end

      def track_ci_secrets_management_usage
        return unless ci_secrets_management_available? && secrets?

        providers = secrets.flat_map { |_secret, config| config.keys.map(&:to_sym) & ::Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS }

        providers.uniq.each do |provider|
          ::Gitlab::UsageDataCounters::HLLRedisCounter.track_event("i_ci_secrets_management_#{provider}_build_created", values: user_id)

          ::Gitlab::Tracking.event(
            self.class.to_s,
            "create_secrets_#{provider}",
            namespace: namespace,
            user: user,
            label: "redis_hll_counters.ci_secrets_management.i_ci_secrets_management_#{provider}_build_created_monthly",
            ultimate_namespace_id: namespace.root_ancestor.id,
            context: [::Gitlab::Tracking::ServicePingContext.new(
              data_source: :redis_hll,
              event: "i_ci_secrets_management_#{provider}_build_created"
            ).to_context]
          )
        end
      end

      def identity_variables
        return [] if options[:identity].blank?

        case options[:identity]
        when 'google_cloud'
          ::Gitlab::Ci::GoogleCloud::GenerateBuildEnvironmentVariablesService.new(self).execute
        else
          raise ArgumentError, "Unknown identity value: #{options[:identity]}"
        end
      end

      def google_artifact_registry_variables
        ::Gitlab::Ci::Variables::Collection.new(
          project.google_cloud_platform_artifact_registry_integration&.ci_variables || []
        )
      end

      def variables_encompassing_secrets_configs
        # We DO NOT need to pass all the build.variables to the Secrets Integration because scoped_variables and
        # job_variables (included in scoped_variables) are the ONLY two subsets of variables that may potentially
        # include information for integration with secrets providers.
        ::Gitlab::Ci::Variables::Collection.new
          .concat(scoped_variables)
      end

      def pages_config
        config = options&.dig(:pages)
        config.is_a?(Hash) ? config : {}
      end

      def expand_variable(value)
        ExpandVariables.expand(value.to_s, -> { base_variables_expanded })
      end

      def base_variables_expanded
        strong_memoize(:base_variables_expanded) do
          base_variables.sort_and_expand_all
        end
      end
    end
  end
end
