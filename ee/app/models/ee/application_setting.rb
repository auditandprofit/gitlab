# frozen_string_literal: true

module EE
  # ApplicationSetting EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `ApplicationSetting` model
  module ApplicationSetting
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      EMAIL_ADDITIONAL_TEXT_CHARACTER_LIMIT = 10_000
      MASK_PASSWORD = '*****'
      ELASTIC_REQUEST_TIMEOUT = 30
      SEAT_CONTROL_OFF = 0
      SEAT_CONTROL_USER_CAP = 1
      SEAT_CONTROL_BLOCK_OVERAGES = 2

      ERROR_NO_SEATS_AVAILABLE = 'NO_SEATS_AVAILABLE'

      belongs_to :file_template_project, class_name: "Project"

      jsonb_accessor :search,
        global_search_code_enabled: [:boolean, { default: true }],
        global_search_commits_enabled: [:boolean, { default: true }],
        global_search_epics_enabled: [:boolean, { default: true }],
        global_search_wiki_enabled: [:boolean, { default: true }],
        global_search_limited_indexing_enabled: [:boolean, { default: false }],
        elastic_migration_worker_enabled: [:boolean, { default: true }]

      jsonb_accessor :zoekt_settings,
        zoekt_cache_response: [:boolean, { default: true }],
        zoekt_indexing_enabled: [:boolean, { default: false }],
        zoekt_indexing_paused: [:boolean, { default: false }],
        zoekt_search_enabled: [:boolean, { default: false }],
        zoekt_auto_index_root_namespace: [:boolean, { default: false }],
        zoekt_cpu_to_tasks_ratio: [:float, { default: 1.0 }],
        zoekt_indexing_parallelism: [:integer, { default: 1 }],
        zoekt_rollout_batch_size: [:integer, { default: 32 }],
        zoekt_indexing_timeout: [:text, { default: ::Search::Zoekt::Settings::DEFAULT_INDEXING_TIMEOUT }],
        zoekt_maximum_files: [:integer, { default: ::Search::Zoekt::Settings::DEFAULT_MAXIMUM_FILES }],
        zoekt_rollout_retry_interval: [:text, { default: ::Search::Zoekt::Settings::DEFAULT_ROLLOUT_RETRY_INTERVAL }],
        zoekt_lost_node_threshold: [:text, { default: ::Search::Zoekt::Settings::DEFAULT_LOST_NODE_THRESHOLD }]

      jsonb_accessor :code_creation, disabled_direct_code_suggestions: [:boolean, { default: false }]

      jsonb_accessor :duo_workflow, duo_workflow_oauth_application_id: [:integer]

      jsonb_accessor :duo_chat,
        duo_chat_expiration_days: [:integer, { default: 30 }],
        duo_chat_expiration_column: [:string, { default: 'last_updated_at' }]

      validates :duo_chat, json_schema: { filename: "application_setting_duo_chat" }
      validates :duo_chat_expiration_column, inclusion: {
        in: Ai::Conversation::Thread::EXPIRATION_COLUMNS,
        message: "must be one of: #{Ai::Conversation::Thread::EXPIRATION_COLUMNS.join(', ')}"
      }

      jsonb_accessor :integrations,
        allow_all_integrations: [:boolean, { default: true }],
        allowed_integrations: [:string, { array: true, default: [] }]

      jsonb_accessor :elasticsearch,
        elasticsearch_aws: [:boolean, { default: false }],
        elasticsearch_search: [:boolean, { default: false }],
        elasticsearch_indexing: [:boolean, { default: false }],
        elasticsearch_username: [:string],
        elasticsearch_aws_region: [:string, { default: 'us-east-1' }],
        elasticsearch_aws_role_arn: [:string],
        elasticsearch_aws_access_key: [:string],
        elasticsearch_limit_indexing: [:boolean, { default: false }],
        elasticsearch_pause_indexing: [:boolean, { default: false }],
        elasticsearch_requeue_workers: [:boolean, { default: false }],
        elasticsearch_max_bulk_size_mb: [:integer, { default: 10 }],
        elasticsearch_retry_on_failure: [:integer, { default: 0 }],
        elasticsearch_max_bulk_concurrency: [:integer, { default: 10 }],
        elasticsearch_client_request_timeout: [:integer, { default: 0 }],
        elasticsearch_worker_number_of_shards: [:integer, { default: 2 }],
        elasticsearch_analyzers_smartcn_search: [:boolean, { default: false }],
        elasticsearch_analyzers_kuromoji_search: [:boolean, { default: false }],
        elasticsearch_analyzers_smartcn_enabled: [:boolean, { default: false }],
        elasticsearch_analyzers_kuromoji_enabled: [:boolean, { default: false }],
        elasticsearch_indexed_field_length_limit: [:integer, { default: 0 }],
        elasticsearch_indexed_file_size_limit_kb: [:integer, { default: 1024 }],
        elasticsearch_max_code_indexing_concurrency: [:integer, { default: 30 }],
        elasticsearch_prefix: [:string, { default: 'gitlab' }]

      validates :search, json_schema: { filename: 'application_setting_ee_search' }
      validates :duo_workflow, json_schema: { filename: "application_setting_duo_workflow" }
      validates :integrations, json_schema: { filename: "application_setting_integrations" }
      validates :elasticsearch, json_schema: { filename: "application_setting_elasticsearch" }

      jsonb_accessor :rate_limits, rate_limits_definition

      jsonb_accessor :identity_verification_settings,
        soft_phone_verification_transactions_daily_limit: [::Gitlab::Database::Type::JsonbInteger.new,
          { default: 16_000 }],
        hard_phone_verification_transactions_daily_limit: [::Gitlab::Database::Type::JsonbInteger.new,
          { default: 20_000 }],
        unverified_account_group_creation_limit: [::Gitlab::Database::Type::JsonbInteger.new, { default: 2 }],
        phone_verification_enabled: [::Gitlab::Database::Type::JsonbBoolean.new, { default: true }],
        ci_requires_identity_verification_on_free_plan: [::Gitlab::Database::Type::JsonbBoolean.new, { default: true }],
        telesign_intelligence_enabled: [::Gitlab::Database::Type::JsonbBoolean.new, { default: true }],
        credit_card_verification_enabled: [::Gitlab::Database::Type::JsonbBoolean.new, { default: true }],
        arkose_labs_enabled: [::Gitlab::Database::Type::JsonbBoolean.new, { default: true }],
        arkose_labs_data_exchange_enabled: [::Gitlab::Database::Type::JsonbBoolean.new, { default: true }]

      validates :identity_verification_settings,
        json_schema: { filename: "identity_verification_settings", detail_errors: true }

      jsonb_accessor :cluster_agents,
        receptive_cluster_agents_enabled: [:boolean, { default: false }]

      jsonb_accessor :user_seat_management,
        seat_control: [:integer, { default: SEAT_CONTROL_OFF }]

      validates :user_seat_management, json_schema: { filename: "application_setting_user_seat_management" }

      validates :shared_runners_minutes,
        numericality: { greater_than_or_equal_to: 0 }

      validates :mirror_max_delay,
        numericality: { only_integer: true, greater_than: :mirror_max_delay_in_minutes }

      validate :mirror_capacity_threshold_less_than

      jsonb_accessor :observability_settings,
        fetch_observability_alerts_from_cloud: [:boolean, { default: true }]

      validates :observability_settings, json_schema: { filename: "application_setting_observability_settings" }

      jsonb_accessor :security_and_compliance_settings,
        enforce_pipl_compliance: [::Gitlab::Database::Type::JsonbBoolean.new, { default: true }]

      validates :security_and_compliance_settings,
        json_schema: { filename: "security_and_compliance_settings", detail_errors: true }

      encrypts :sdrs_jwt_signing_key

      validates :sdrs_jwt_signing_key, json_schema: { filename: 'application_setting_sdrs_jwt_signing_key' },
        allow_nil: true
      validates :sdrs_jwt_signing_key, length: { maximum: 10_000 }

      validates :mirror_capacity_threshold,
        :mirror_max_capacity,
        :elasticsearch_indexed_file_size_limit_kb,
        :elasticsearch_max_bulk_concurrency,
        :elasticsearch_max_bulk_size_mb,
        :search_max_docs_denominator,
        :search_min_docs_before_rollover,
        :search_max_shard_size_gb,
        numericality: { only_integer: true, greater_than: 0 }

      validates :elasticsearch_max_code_indexing_concurrency,
        :elasticsearch_retry_on_failure,
        presence: true,
        numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      validates :namespace_storage_forks_cost_factor,
        presence: true,
        numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

      validates :elasticsearch_url,
        presence: { message: "can't be blank when indexing is enabled" },
        if: ->(setting) { setting.elasticsearch_indexing? }

      validates :elasticsearch_username, length: { maximum: 255 }
      validates :elasticsearch_password, length: { maximum: 255 }

      validates :elasticsearch_prefix,
        presence: true,
        length: { minimum: 1, maximum: 100 },
        format: {
          with: /\A[a-z0-9]([a-z0-9_-]*[a-z0-9])?\z/,
          message: 'must contain only lowercase alphanumeric characters, hyphens, ' \
            'and underscores, and cannot start or end with a hyphen or underscore'
        }

      validate :elasticsearch_prefix_no_whitespace

      validate :check_elasticsearch_url_scheme, if: :elasticsearch_url_changed?

      validate :check_allowed_integrations, if: :allowed_integrations_changed?

      validates :elasticsearch_aws_region,
        presence: { message: "can't be blank when using aws hosted elasticsearch" },
        if: ->(setting) { setting.elasticsearch_aws? && setting.elasticsearch_indexing? }

      validates :elasticsearch_worker_number_of_shards,
        presence: true,
        numericality: { only_integer: true, greater_than: 0,
                        less_than_or_equal_to: Elastic::ProcessBookkeepingService::SHARDS_MAX }

      validates :email_additional_text,
        allow_blank: true,
        length: { maximum: EMAIL_ADDITIONAL_TEXT_CHARACTER_LIMIT }

      attribute :future_subscriptions, ::Gitlab::Database::Type::IndifferentJsonb.new
      validates :future_subscriptions, json_schema: { filename: 'future_subscriptions' }

      validates :required_instance_ci_template, presence: true, allow_nil: true

      validates :geo_node_allowed_ips, length: { maximum: 255 }, presence: true
      validate :check_geo_node_allowed_ips

      validates :globally_allowed_ips, length: { maximum: 255 }, allow_blank: true
      validate :check_globally_allowed_ips

      validates :max_personal_access_token_lifetime,
        :max_ssh_key_lifetime,
        allow_blank: true,
        numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: :max_auth_lifetime }

      validates :new_user_signups_cap, absence: true, if: -> {
        [SEAT_CONTROL_OFF, SEAT_CONTROL_BLOCK_OVERAGES].include?(seat_control)
      }

      validates :new_user_signups_cap,
        numericality: { only_integer: true, greater_than: 0 }, if: -> { seat_control == SEAT_CONTROL_USER_CAP }

      validates :git_two_factor_session_expiry,
        presence: true,
        numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 10080 }

      validates :max_number_of_repository_downloads,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 }

      validates :max_number_of_repository_downloads_within_time_period,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10.days.to_i }

      validates :git_rate_limit_users_allowlist,
        length: { maximum: 100, message: ->(_object, _data) { _("exceeds maximum length (100 usernames)") } },
        allow_nil: false,
        user_existence: true,
        if: :git_rate_limit_users_allowlist_changed?

      validates :git_rate_limit_users_alertlist,
        length: { maximum: 100, message: ->(_object, _data) { _("exceeds maximum length (100 user ids)") } },
        allow_nil: false,
        user_id_existence: true,
        if: :git_rate_limit_users_alertlist_changed?

      validates :dashboard_limit,
        :repository_size_limit,
        :elasticsearch_indexed_field_length_limit,
        :elasticsearch_client_request_timeout,
        :virtual_registries_endpoints_api_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      validates :dashboard_limit_enabled, inclusion: { in: [true, false], message: 'must be a boolean value' }

      validates :cube_api_base_url,
        length: { maximum: 512 },
        addressable_url: ::ApplicationSetting::ADDRESSABLE_URL_VALIDATION_OPTIONS.merge({ allow_localhost: true }),
        presence: true,
        if: :product_analytics_enabled

      validates :product_analytics_enabled,
        presence: true,
        allow_blank: true

      validates :cube_api_key,
        length: { maximum: 255 },
        presence: true,
        if: :product_analytics_enabled

      validates :product_analytics_configurator_connection_string,
        length: { maximum: 512 },
        addressable_url: ::ApplicationSetting::ADDRESSABLE_URL_VALIDATION_OPTIONS.merge({ allow_localhost: true }),
        presence: true,
        if: ->(setting) { setting.product_analytics_enabled }

      validates :security_policy_global_group_approvers_enabled,
        inclusion: { in: [true, false], message: 'must be a boolean value' }

      validates :security_approval_policies_limit,
        numericality: {
          only_integer: true,
          greater_than_or_equal_to: 5,
          less_than_or_equal_to: ::Security::ScanResultPolicy::POLICIES_LIMIT
        }

      validates :security_policies, json_schema: { filename: "application_setting_security_policies" }

      jsonb_accessor :security_policies, scan_execution_policies_action_limit: [:integer, { default: 0 }]
      jsonb_accessor :security_policies, scan_execution_policies_schedule_limit: [:integer, { default: 0 }]
      jsonb_accessor :security_policies, pipeline_execution_policies_per_configuration_limit: [:integer, { default: 5 }]
      jsonb_accessor :security_policies, scan_execution_policies_per_configuration_limit: [:integer, { default: 5 }]
      jsonb_accessor :security_policies,
        vulnerability_management_policies_per_configuration_limit: [:integer, { default: 5 }]

      validates :scan_execution_policies_action_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }
      validates :scan_execution_policies_schedule_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }
      validates :pipeline_execution_policies_per_configuration_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }
      validates :scan_execution_policies_per_configuration_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }
      validates :vulnerability_management_policies_per_configuration_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }

      validates :product_analytics_data_collector_host,
        length: { maximum: 255 },
        addressable_url: ::ApplicationSetting::ADDRESSABLE_URL_VALIDATION_OPTIONS.merge({ allow_localhost: true }),
        presence: true,
        if: :product_analytics_enabled

      validates :package_metadata_purl_types, inclusion: { in: ::Enums::Sbom.purl_types.values }

      validates :allow_account_deletion,
        inclusion: { in: [true, false], message: N_('must be a boolean value') }

      validates :delete_unconfirmed_users,
        inclusion: { in: [true, false], message: N_('must be a boolean value') },
        unless: :email_confirmation_setting_off?

      validates :delete_unconfirmed_users,
        inclusion: { in: [false], message: N_('must be false when email confirmation setting is off') },
        if: :email_confirmation_setting_off?

      validates :unconfirmed_users_delete_after_days,
        numericality: { only_integer: true, greater_than: 0 },
        unless: :email_confirmation_setting_soft?

      validates :unconfirmed_users_delete_after_days,
        numericality: { only_integer: true, greater_than: proc { Devise.allow_unconfirmed_access_for.in_days.to_i } },
        if: :email_confirmation_setting_soft?

      validates :secret_push_protection_available,
        inclusion: { in: [true, false], message: N_('must be a boolean value') },
        if: :gitlab_dedicated_instance

      validates :instance_level_ai_beta_features_enabled,
        allow_nil: false,
        inclusion: { in: [true, false], message: N_('must be a boolean value') }

      validates :zoekt_settings, json_schema: { filename: 'application_setting_zoekt_settings' }
      validates :zoekt_cpu_to_tasks_ratio, numericality: { greater_than: 0.0 }
      validates :zoekt_indexing_parallelism, numericality: { greater_than: 0 }
      validates :zoekt_rollout_batch_size, numericality: { greater_than: 0 }
      validates :zoekt_indexing_timeout, format: {
        with: ::Search::Zoekt::Settings::DURATION_INTERVAL_DISABLED_NOT_ALLOWED_REGEX,
        message: N_('Must be in the following format: `30m`, `2h`, or `1d`')
      }
      validates :zoekt_maximum_files, numericality: { greater_than: 0 }
      validates :zoekt_rollout_retry_interval, format: {
        with: ::Search::Zoekt::Settings::DURATION_INTERVAL_REGEX,
        message: N_('Must be in the following format: `30m`, `2h`, or `1d`')
      }
      validates :zoekt_lost_node_threshold, format: {
        with: ::Search::Zoekt::Settings::DURATION_INTERVAL_REGEX,
        message: N_('Must be in the following format: `30m`, `2h`, or `1d`')
      }

      validates :code_creation, json_schema: { filename: 'application_setting_code_creation' }

      validates :observability_backend_ssl_verification_enabled,
        allow_nil: false,
        inclusion: { in: [true, false], message: N_('must be a boolean value') }

      after_commit :update_personal_access_tokens_lifetime, if: :saved_change_to_max_personal_access_token_lifetime?
      after_commit :trigger_clickhouse_for_analytics_enabled_event
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :defaults
      def defaults
        super.merge(
          # As an exception, we need Elasticsearch default settings with jsonb accessor
          # because they are needed for the E2E specs, contrary to the docs:
          # https://docs.gitlab.com/development/application_settings/#default-values
          # Please follow https://gitlab.com/gitlab-org/gitlab/-/issues/553575 for updates
          jsonb_defaults_mapping_for_elasticsearch.transform_keys(&:to_sym)
        ).merge(
          allow_group_owners_to_manage_ldap: true,
          automatic_purchased_storage_allocation: false,
          custom_project_templates_group_id: nil,
          dashboard_limit_enabled: false,
          dashboard_limit: 0,
          default_project_deletion_protection: false,
          disable_personal_access_tokens: false,
          elasticsearch_url: ENV['ELASTIC_URL'] || 'http://localhost:9200',
          email_additional_text: nil,
          enforce_namespace_storage_limit: false,
          future_subscriptions: [],
          geo_node_allowed_ips: '0.0.0.0/0, ::/0',
          git_two_factor_session_expiry: 15,
          globally_allowed_ips: '',
          license_usage_data_exported: false,
          lock_memberships_to_ldap: false,
          lock_memberships_to_saml: false,
          maintenance_mode: false,
          max_personal_access_token_lifetime: nil,
          max_ssh_key_lifetime: nil,
          mirror_capacity_threshold: Settings.gitlab['mirror_capacity_threshold'],
          mirror_max_capacity: Settings.gitlab['mirror_max_capacity'],
          mirror_max_delay: Settings.gitlab['mirror_max_delay'],
          repository_size_limit: 0,
          secret_detection_token_revocation_enabled: false,
          secret_detection_token_revocation_url: nil,
          secret_detection_token_revocation_token: nil,
          secret_detection_revocation_token_types_url: nil,
          max_number_of_repository_downloads: 0,
          max_number_of_repository_downloads_within_time_period: 0,
          git_rate_limit_users_allowlist: [],
          git_rate_limit_users_alertlist: [],
          auto_ban_user_on_excessive_projects_download: false,
          product_analytics_enabled: false,
          product_analytics_data_collector_host: nil,
          product_analytics_configurator_connection_string: nil,
          cube_api_base_url: nil,
          cube_api_key: nil,
          secret_detection_service_url: '',
          secret_detection_service_auth_token: nil
        )
      end

      override :non_production_defaults
      def non_production_defaults
        super.merge(
          search_max_shard_size_gb: 1,
          search_max_docs_denominator: 100,
          search_min_docs_before_rollover: 50
        )
      end

      override :rate_limits_definition
      def rate_limits_definition
        super.merge(
          virtual_registries_endpoints_api_limit: [:integer, { default: 1000 }]
        )
      end
    end

    def allowed_integrations_raw=(value)
      self.allowed_integrations = ::Gitlab::Json.parse(value)
    end

    def max_auth_lifetime
      if ::Feature.enabled?(:buffered_token_expiration_limit)
        400
      else
        365
      end
    end

    def elasticsearch_namespace_ids
      ElasticsearchIndexedNamespace.target_ids
    end

    def elasticsearch_project_ids
      ElasticsearchIndexedProject.target_ids
    end

    def elasticsearch_shards
      Elastic::IndexSetting.number_of_shards
    end

    def elasticsearch_replicas
      Elastic::IndexSetting.number_of_replicas
    end

    def elasticsearch_indexes_project?(project)
      return false unless elasticsearch_indexing?
      return true unless elasticsearch_limit_indexing?

      ::Gitlab::Elastic::ElasticsearchEnabledCache.fetch(:project, project.id) do
        elasticsearch_limited_project_exists?(project)
      end
    end

    def elasticsearch_indexes_namespace?(namespace)
      return false unless elasticsearch_indexing?
      return true unless elasticsearch_limit_indexing?

      ::Gitlab::Elastic::ElasticsearchEnabledCache.fetch(:namespace, namespace.id) do
        ElasticsearchIndexedNamespace.where(namespace_id: namespace.traversal_ids).exists?
      end
    end

    def invalidate_elasticsearch_indexes_cache!
      ::Gitlab::Elastic::ElasticsearchEnabledCache.delete(:project)
      ::Gitlab::Elastic::ElasticsearchEnabledCache.delete(:namespace)
    end

    def invalidate_elasticsearch_indexes_cache_for_project!(project_id)
      ::Gitlab::Elastic::ElasticsearchEnabledCache.delete_record(:project, project_id)
    end

    def invalidate_elasticsearch_indexes_cache_for_namespace!(namespace_id)
      ::Gitlab::Elastic::ElasticsearchEnabledCache.delete_record(:namespace, namespace_id)
    end

    def elasticsearch_limited_projects(ignore_namespaces = false)
      return ::Project.where(id: ElasticsearchIndexedProject.select(:project_id)) if ignore_namespaces

      union = ::Gitlab::SQL::Union.new([
        ::Project.where(namespace_id: elasticsearch_limited_namespaces.select(:id)),
        ::Project.where(id: ElasticsearchIndexedProject.select(:project_id))
      ]).to_sql

      ::Project.from("(#{union}) projects")
    end

    def elasticsearch_limited_namespaces(ignore_descendants = false)
      namespaces = ::Namespace.where(id: ElasticsearchIndexedNamespace.select(:namespace_id))

      return namespaces if ignore_descendants

      namespaces.self_and_descendants
    end

    def should_check_namespace_plan?
      check_namespace_plan? && (Rails.env.test? || ::Gitlab.org_or_com?)
    end

    def elasticsearch_indexing
      super && License.feature_available?(:elastic_search) # rubocop:disable Gitlab/LicenseAvailableUsage -- Does not have cyclical dependency
    end
    alias_method :elasticsearch_indexing?, :elasticsearch_indexing

    def elasticsearch_search
      super && License.feature_available?(:elastic_search) # rubocop:disable Gitlab/LicenseAvailableUsage -- Does not have cyclical dependency
    end
    alias_method :elasticsearch_search?, :elasticsearch_search

    # Determines whether a search should use elasticsearch, taking the scope
    # (nil for global search, otherwise a namespace or project) into account
    def search_using_elasticsearch?(scope: nil)
      return false unless elasticsearch_indexing? && elasticsearch_search?
      return true unless elasticsearch_limit_indexing?

      case scope
      when Namespace
        elasticsearch_indexes_namespace?(scope)
      when Project
        elasticsearch_indexes_project?(scope)
      else
        ::Gitlab::CurrentSettings.global_search_limited_indexing_enabled?
      end
    end

    def elasticsearch_url
      read_attribute(:elasticsearch_url).split(',').map do |s|
        URI.parse(s.strip)
      end
    end

    def elasticsearch_url=(values)
      cleaned = values.split(',').map { |url| url.strip.gsub(%r{/*\z}, '') }

      write_attribute(:elasticsearch_url, cleaned.join(','))
    end

    def elasticsearch_password=(value)
      return if value == MASK_PASSWORD

      super
    end

    def elasticsearch_aws_secret_access_key=(value)
      return if value == MASK_PASSWORD

      super
    end

    def elasticsearch_url_with_credentials
      elasticsearch_url.map do |uri|
        ::Gitlab::Elastic::Helper.connection_settings(uri: uri, user: elasticsearch_username,
          password: elasticsearch_password)
      end
    end

    def elasticsearch_config
      client_request_timeout = Rails.env.test? ? ELASTIC_REQUEST_TIMEOUT : elasticsearch_client_request_timeout

      {
        url: elasticsearch_url_with_credentials,
        aws: elasticsearch_aws,
        aws_access_key: elasticsearch_aws_access_key,
        aws_secret_access_key: elasticsearch_aws_secret_access_key,
        aws_region: elasticsearch_aws_region,
        aws_role_arn: elasticsearch_aws_role_arn,
        max_bulk_size_bytes: elasticsearch_max_bulk_size_mb.megabytes,
        max_bulk_concurrency: elasticsearch_max_bulk_concurrency,
        client_request_timeout: (client_request_timeout if client_request_timeout > 0)
      }.compact
    end

    def email_additional_text_character_limit
      EMAIL_ADDITIONAL_TEXT_CHARACTER_LIMIT
    end

    def custom_project_templates_enabled?
      License.feature_available?(:custom_project_templates) # rubocop:disable Gitlab/LicenseAvailableUsage -- Does not have cyclical dependency
    end

    def custom_project_templates_group_id
      super if super.present? && custom_project_templates_enabled?
    end

    def available_custom_project_templates(subgroup_id = nil)
      group_id = subgroup_id || custom_project_templates_group_id

      return ::Project.none unless group_id

      ::Project.where(namespace_id: group_id)
    end

    override :instance_review_permitted?
    def instance_review_permitted?
      return false if License.current

      super
    end

    def max_personal_access_token_lifetime_from_now
      return unless max_personal_access_token_lifetime

      Date.current + max_personal_access_token_lifetime
    end

    def max_ssh_key_lifetime_from_now
      max_ssh_key_lifetime&.days&.from_now
    end

    def compliance_frameworks=(values)
      cleaned = Array.wrap(values).reject(&:blank?).sort.uniq

      write_attribute(:compliance_frameworks, cleaned)
    end

    override :personal_access_tokens_disabled?
    def personal_access_tokens_disabled?
      ::Gitlab::CurrentSettings.disable_personal_access_tokens &&
        License.feature_available?(:disable_personal_access_tokens) # rubocop:disable Gitlab/LicenseAvailableUsage -- Does not have cyclical dependency as it's not used in Registration features
    end

    def disable_feed_token
      personal_access_tokens_disabled? || read_attribute(:disable_feed_token)
    end
    alias_method :disable_feed_token?, :disable_feed_token

    def git_rate_limit_users_alertlist
      (self[:git_rate_limit_users_alertlist].presence || ::User.admins.active.pluck_primary_key).sort
    end

    def package_metadata_purl_types_names
      ::Enums::Sbom.purl_types_numerical.values_at(*package_metadata_purl_types)
    end

    def unique_project_download_limit_enabled?
      if max_number_of_repository_downloads.nonzero? && max_number_of_repository_downloads_within_time_period.nonzero?
        return true
      end

      false
    end

    def duo_availability
      if duo_features_enabled && !lock_duo_features_enabled
        :default_on
      elsif !duo_features_enabled && !lock_duo_features_enabled
        :default_off
      else
        :never_on
      end
    end

    def duo_availability=(value)
      if value == "default_on"
        self.duo_features_enabled = true
        self.lock_duo_features_enabled = false
      elsif value == "default_off"
        self.duo_features_enabled = false
        self.lock_duo_features_enabled = false
      else
        self.duo_features_enabled = false
        self.lock_duo_features_enabled = true
        self.instance_level_ai_beta_features_enabled = false
      end
    end

    def duo_never_on?
      duo_availability == :never_on
    end

    def enabled_expanded_logging
      ::Ai::Setting.instance.enabled_instance_verbose_ai_logs
    end

    def enabled_expanded_logging=(value)
      ::Ai::Setting.instance.update!(enabled_instance_verbose_ai_logs: value)
    end

    def seat_control_user_cap?
      return false unless License.feature_available?(:seat_control) # rubocop:disable Gitlab/LicenseAvailableUsage -- Does not have cyclical dependency as it's not used for Registration features

      seat_control == SEAT_CONTROL_USER_CAP
    end

    def seat_control_block_overages?
      return false unless License.feature_available?(:seat_control) # rubocop:disable Gitlab/LicenseAvailableUsage -- Does not have cyclical dependency as it's not used for Registration features

      seat_control == SEAT_CONTROL_BLOCK_OVERAGES
    end

    private

    def elasticsearch_limited_project_exists?(project)
      project_namespaces = ::Namespace.where(id: project.namespace_id)
      self_and_ancestors_namespaces = project_namespaces.self_and_ancestors.joins(:elasticsearch_indexed_namespace)

      indexed_namespaces = ::Project.where('EXISTS (?)', self_and_ancestors_namespaces)
      indexed_projects = ::Project.where('EXISTS (?)', ElasticsearchIndexedProject.where(project_id: project.id))

      ::Project
        .from("(SELECT) as projects") # SELECT from "nothing" since the EXISTS queries have all the conditions.
        .merge(indexed_namespaces.or(indexed_projects))
        .exists?
    end

    def update_personal_access_tokens_lifetime
      return unless max_personal_access_token_lifetime.present? && License.feature_available?(:personal_access_token_expiration_policy) # rubocop:disable Gitlab/LicenseAvailableUsage -- Does not have cyclical dependency as it's not used for Registration features

      ::PersonalAccessTokens::Instance::UpdateLifetimeService.new.execute
    end

    def mirror_max_delay_in_minutes
      ::Gitlab::Mirror.min_delay_upper_bound / 60
    end

    def mirror_capacity_threshold_less_than
      return unless mirror_max_capacity && mirror_capacity_threshold

      return unless mirror_capacity_threshold > mirror_max_capacity

      errors.add(:mirror_capacity_threshold,
        "Project's mirror capacity threshold can't be higher than it's maximum capacity")
    end

    def check_geo_node_allowed_ips
      ::Gitlab::CIDR.new(geo_node_allowed_ips)
    rescue ::Gitlab::CIDR::ValidationError => e
      errors.add(:geo_node_allowed_ips, e.message)
    end

    def check_globally_allowed_ips
      ::Gitlab::CIDR.new(globally_allowed_ips)
    rescue ::Gitlab::CIDR::ValidationError => e
      errors.add(:globally_allowed_ips, e.message)
    end

    def elasticsearch_prefix_no_whitespace
      return unless elasticsearch_prefix
      return unless elasticsearch_prefix != elasticsearch_prefix.strip

      errors.add(:elasticsearch_prefix, 'cannot contain leading or trailing whitespace')
    end

    def check_elasticsearch_url_scheme
      # ElasticSearch only exposes a RESTful API, hence we need
      # to use the HTTP protocol on all URLs.
      elasticsearch_url.each do |str|
        ::Gitlab::HTTP_V2::UrlBlocker.validate!(str,
          schemes: %w[http https],
          allow_localhost: true,
          dns_rebind_protection: false,
          deny_all_requests_except_allowed: deny_all_requests_except_allowed?,
          outbound_local_requests_allowlist: outbound_local_requests_whitelist) # rubocop:disable Naming/InclusiveLanguage -- existing setting
      end
    rescue ::Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError
      errors.add(:elasticsearch_url, "only supports valid HTTP(S) URLs.")
    end

    def check_allowed_integrations
      unknown_integrations = allowed_integrations - ::Integration.all_integration_names

      return if unknown_integrations.blank?

      errors.add(:allowed_integrations, 'contains unknown integration names')
    end

    def trigger_clickhouse_for_analytics_enabled_event
      return if !saved_change_to_use_clickhouse_for_analytics? || !use_clickhouse_for_analytics?

      ::Gitlab::EventStore.publish(
        ::Analytics::ClickHouseForAnalyticsEnabledEvent.new(data: { enabled_at: updated_at.iso8601 })
      )
    end
  end
end
