# frozen_string_literal: true

module EE
  module Types
    module QueryType
      extend ActiveSupport::Concern
      prepended do
        field :add_on_purchases,
          [::Types::GitlabSubscriptions::AddOnPurchaseType],
          null: true,
          description: 'Retrieve all active add-on purchases. ' \
                       'This query can be used in GitLab.com and self-managed environments.',
          resolver: ::Resolvers::GitlabSubscriptions::AddOnPurchasesResolver
        field :ai_catalog_built_in_tools, ::Types::Ai::Catalog::BuiltInToolType.connection_type,
          null: false,
          description: 'List of AI Catalog built-in tools.',
          experiment: { milestone: '18.3' }
        field :ai_catalog_item,
          resolver: ::Resolvers::Ai::Catalog::ItemResolver,
          null: true,
          experiment: { milestone: '18.2' }
        field :ai_catalog_items,
          resolver: ::Resolvers::Ai::Catalog::ItemsResolver,
          null: false,
          experiment: { milestone: '18.2' },
          description: 'List of AI Catalog items.'
        field :blob_search, ::Types::Search::Blob::BlobSearchType,
          null: true,
          resolver: ::Resolvers::Search::Blob::BlobSearchResolver,
          experiment: { milestone: '17.2' },
          description: 'Find code visible to the current user'
        field :ci_minutes_usage, ::Types::Ci::Minutes::NamespaceMonthlyUsageType.connection_type,
          null: true,
          description: 'Compute usage data for a namespace.' do
          argument :namespace_id, ::Types::GlobalIDType[::Namespace],
            required: false,
            description: 'Global ID of the Namespace for the monthly compute usage.'
          argument :date, ::Types::DateType,
            required: false,
            description: 'Date for which to retrieve the usage data, should be the first day of a month.'
        end
        field :ci_dedicated_hosted_runner_filters, Types::Ci::Minutes::DedicatedRunnerFiltersType,
          null: true,
          fallback_value: {},
          description: 'Returns available filters for GitLab Dedicated runner usage data.'
        field :ci_dedicated_hosted_runner_usage, Types::Ci::Minutes::DedicatedMonthlyUsageType.connection_type,
          null: true,
          resolver: EE::Resolvers::Ci::Minutes::DedicatedMonthlyUsageResolver,
          description: 'Compute usage data for runners across namespaces on GitLab Dedicated. ' \
                       'Defaults to the current year if no year or billing month is specified. ' \
                       'Ultimate only.' do
          argument :billing_month, ::Types::DateType,
            required: false,
            description: 'First day of the month to retrieve data for.'
          argument :year, GraphQL::Types::Int,
            required: false,
            description: 'Year to retrieve data for.'
          argument :grouping,
            type: EE::Types::Ci::Minutes::GroupingEnum,
            required: false,
            description: 'Groups usage data by instance aggregate or root namespace.'
          argument :runner_id, ::Types::GlobalIDType[::Ci::Runner],
            required: false,
            description: 'Runner ID to retrieve data for.'
        end
        field :configured_ai_catalog_items,
          resolver: ::Resolvers::Ai::Catalog::ConfiguredItemsResolver,
          null: false,
          description: 'AI Catalog items configured for use.',
          experiment: { milestone: '18.2' }
        field :current_license, ::Types::Admin::CloudLicenses::CurrentLicenseType,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::CurrentLicenseResolver,
          description: 'Fields related to the current license.'
        field :devops_adoption_enabled_namespaces,
          null: true,
          description: 'Get configured DevOps adoption namespaces. **Status**: Beta. This endpoint is subject to ' \
                       'change without notice.',
          resolver: ::Resolvers::Analytics::DevopsAdoption::EnabledNamespacesResolver
        field :epic_board_list, ::Types::Boards::EpicListType,
          null: true,
          resolver: ::Resolvers::Boards::EpicListResolver
        field :geo_node, ::Types::Geo::GeoNodeType,
          null: true,
          resolver: ::Resolvers::Geo::GeoNodeResolver,
          description: 'Find a Geo node.'
        field :iteration, ::Types::IterationType,
          null: true,
          description: 'Find an iteration.' do
          argument :id, ::Types::GlobalIDType[::Iteration],
            required: true,
            description: 'Find an iteration by its ID.'
        end
        field :instance_security_dashboard, ::Types::InstanceSecurityDashboardType,
          null: true,
          resolver: ::Resolvers::InstanceSecurityDashboardResolver,
          description: 'Fields related to Instance Security Dashboard.'
        field :license_history_entries, ::Types::Admin::CloudLicenses::LicenseHistoryEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::LicenseHistoryEntriesResolver,
          description: 'Fields related to entries in the license history.'
        field :subscription_future_entries, ::Types::Admin::CloudLicenses::SubscriptionFutureEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::SubscriptionFutureEntriesResolver,
          description: 'Fields related to entries in future subscriptions.'
        field :vulnerabilities,
          ::Types::VulnerabilityType.connection_type,
          null: true,
          extras: [:lookahead],
          description: "Vulnerabilities reported on projects on the current user's instance security dashboard.",
          resolver: ::Resolvers::VulnerabilitiesResolver,
          scopes: [:api, :read_api, :ai_workflows]
        field :vulnerabilities_count_by_day,
          ::Types::VulnerabilitiesCountByDayType.connection_type,
          null: true,
          resolver: ::Resolvers::VulnerabilitiesCountPerDayResolver,
          description: "The historical number of vulnerabilities per day for the projects on the current " \
                       "user's instance security dashboard."
        field :vulnerability,
          ::Types::VulnerabilityType,
          null: true,
          scopes: [:api, :read_api, :ai_workflows],
          description: "Find a vulnerability." do
          argument :id, ::Types::GlobalIDType[::Vulnerability],
            required: true,
            description: 'Global ID of the Vulnerability.'
        end
        field :dependency,
          ::Types::Sbom::DependencyType,
          null: true,
          description: "Find a dependency." do
          argument :id, ::Types::GlobalIDType[::Sbom::Occurrence],
            required: true,
            description: 'Global ID of the Dependency.'
        end
        field :workspace, ::Types::RemoteDevelopment::WorkspaceType,
          null: true,
          description: 'Find a workspace.' do
          argument :id, ::Types::GlobalIDType[::RemoteDevelopment::Workspace],
            required: true,
            description: 'Find a workspace by its ID.'
        end
        field :workspaces,
          ::Types::RemoteDevelopment::WorkspaceType.connection_type,
          null: true,
          resolver: ::Resolvers::RemoteDevelopment::WorkspacesAdminResolver,
          description: 'Find workspaces across the entire instance. This field is only available to instance admins, ' \
                       'it will return an empty result for all non-admins.'
        field :instance_external_audit_event_destinations,
          ::Types::AuditEvents::InstanceExternalAuditEventDestinationType.connection_type,
          null: true,
          description: 'Instance level external audit event destinations.',
          resolver: ::Resolvers::AuditEvents::InstanceExternalAuditEventDestinationsResolver

        field :ai_conversation_threads, ::Types::Ai::Conversations::ThreadType.connection_type,
          resolver: ::Resolvers::Ai::Conversations::ThreadsResolver,
          experiment: { milestone: '17.9' },
          description: 'List conversation threads of AI features.'

        field :ai_messages, ::Types::Ai::MessageType.connection_type,
          resolver: ::Resolvers::Ai::ChatMessagesResolver,
          experiment: { milestone: '16.1' },
          description: 'Find GitLab Duo Chat messages.'

        field :duo_workflow_events, ::Types::Ai::DuoWorkflows::WorkflowEventType.connection_type,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkflowEventsResolver,
          experiment: { milestone: '17.2' },
          description: 'List the events for a Duo Workflow.'

        field :duo_workflow_workflows, ::Types::Ai::DuoWorkflows::WorkflowType.connection_type,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkflowsResolver,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          experiment: { milestone: '17.2' },
          description: 'List the workflows owned by the current user.'

        field :ci_queueing_history,
          ::Types::Ci::QueueingHistoryType,
          null: true,
          description: 'Time taken for CI jobs to be picked up by runner by percentile. ' \
            'Enable the ClickHouse database backend to use this query.',
          resolver: ::Resolvers::Ci::InstanceQueueingHistoryResolver,
          extras: [:lookahead]
        field :runner_usage_by_project,
          [::Types::Ci::RunnerUsageByProjectType],
          null: true,
          description: 'Runner usage by project. Enable the ClickHouse database backend to use this query.',
          resolver: ::Resolvers::Ci::RunnerUsageByProjectResolver
        field :runner_usage,
          [::Types::Ci::RunnerUsageType],
          null: true,
          description: 'Runner usage by runner. Enable the ClickHouse database backend to use this query.',
          resolver: ::Resolvers::Ci::RunnerUsageResolver

        field :instance_google_cloud_logging_configurations,
          ::Types::AuditEvents::Instance::GoogleCloudLoggingConfigurationType.connection_type,
          null: true,
          description: 'Instance level google cloud logging configurations.',
          resolver: ::Resolvers::AuditEvents::Instance::GoogleCloudLoggingConfigurationsResolver
        field :member_role_permissions,
          ::Types::Members::CustomizableStandardPermissionType.connection_type,
          null: true,
          description: 'List of all standard customizable permissions.',
          experiment: { milestone: '16.4' }
        field :admin_member_role_permissions,
          ::Types::Members::CustomizableAdminPermissionType.connection_type,
          description: 'List of all admin customizable permissions.',
          experiment: { milestone: '17.9' }
        field :member_role, ::Types::MemberRoles::MemberRoleType,
          null: true,
          description: 'Finds a single custom role for the instance. Available only for GitLab Self-Managed.',
          resolver: ::Resolvers::MemberRoles::RolesResolver.single,
          experiment: { milestone: '16.6' }
        field :admin_member_role,
          ::Types::Members::AdminMemberRoleType,
          description: 'Finds a single admin custom role for the instance. Available only for GitLab Self-Managed.',
          resolver: ::Resolvers::Members::AdminRolesResolver.single,
          experiment: { milestone: '17.10' }
        field :standard_role, ::Types::Members::StandardRoleType,
          null: true,
          description: 'Finds a single default role for the instance. Available only for GitLab Self-Managed.',
          resolver: ::Resolvers::Members::StandardRolesResolver.single,
          experiment: { milestone: '17.6' }
        field :standard_roles, ::Types::Members::StandardRoleType.connection_type,
          null: true, description: 'Default roles available for the instance. Available only for GitLab Self-Managed.',
          resolver: ::Resolvers::Members::StandardRolesResolver,
          experiment: { milestone: '17.3' }
        field :self_managed_add_on_eligible_users,
          ::Types::GitlabSubscriptions::AddOnUserType.connection_type,
          null: true,
          description: 'Users within the self-managed instance who are eligible for add-ons.',
          resolver: ::Resolvers::GitlabSubscriptions::SelfManaged::AddOnEligibleUsersResolver,
          experiment: { milestone: '16.7' }
        field :self_managed_users_queued_for_role_promotion,
          EE::Types::GitlabSubscriptions::MemberManagement::UsersQueuedForRolePromotionType.connection_type,
          null: true,
          resolver: ::Resolvers::GitlabSubscriptions::MemberManagement::SelfManaged::
              UsersQueuedForRolePromotionResolver,
          description: 'Fields related to users within a self-managed instance that are pending role ' \
                       'promotion approval.'
        field :audit_events_instance_amazon_s3_configurations,
          ::Types::AuditEvents::Instance::AmazonS3ConfigurationType.connection_type,
          null: true,
          description: 'Instance-level Amazon S3 configurations for audit events.',
          resolver: ::Resolvers::AuditEvents::Instance::AmazonS3ConfigurationsResolver
        field :member_roles, ::Types::MemberRoles::MemberRoleType.connection_type,
          null: true, description: 'Custom roles available for the instance. Available only for GitLab Self-Managed.',
          resolver: ::Resolvers::MemberRoles::RolesResolver,
          experiment: { milestone: '16.7' }
        field :admin_member_roles,
          ::Types::Members::AdminMemberRoleType.connection_type,
          description: 'Admin custom roles available for the instance. Available only for GitLab Self-Managed.',
          resolver: ::Resolvers::Members::AdminRolesResolver,
          experiment: { milestone: '17.10' }
        field :google_cloud_artifact_registry_repository_artifact,
          ::Types::GoogleCloud::ArtifactRegistry::ArtifactDetailsType,
          null: true,
          description: 'Details about an artifact in the Google Artifact Registry.',
          resolver: ::Resolvers::GoogleCloud::ArtifactRegistry::ArtifactResolver,
          experiment: { milestone: '16.10' }
        field :audit_events_instance_streaming_destinations,
          ::Types::AuditEvents::Instance::StreamingDestinationType.connection_type,
          null: true,
          description: 'Instance-level external audit event streaming destinations.',
          resolver: ::Resolvers::AuditEvents::Instance::StreamingDestinationsResolver,
          experiment: { milestone: '16.11' }

        field :ai_self_hosted_models,
          ::Types::Ai::SelfHostedModels::SelfHostedModelType.connection_type,
          null: true,
          resolver: ::Resolvers::Ai::SelfHostedModels::SelfHostedModelsResolver,
          experiment: { milestone: '17.1' },
          description: 'Returns the self-hosted model if an ID is provided, otherwise returns all models.' do
            argument :id, ::Types::GlobalIDType[::Ai::SelfHostedModel],
              required: false,
              description: "Global ID of a self-hosted model."
          end

        field :cloud_connector_status,
          ::Types::CloudConnector::StatusType,
          null: true,
          description: 'Run a series of status checks for Cloud Connector features.',
          resolver: ::Resolvers::CloudConnector::StatusResolver,
          experiment: { milestone: '17.3' }

        field :project_secrets_manager, ::Types::SecretsManagement::ProjectSecretsManagerType,
          null: true,
          experiment: { milestone: '17.4' },
          description: 'Find a project secrets manager.',
          resolver: ::Resolvers::SecretsManagement::ProjectSecretsManagerResolver

        field :project_secrets, ::Types::SecretsManagement::ProjectSecretType.connection_type,
          null: true,
          experiment: { milestone: '17.8' },
          description: 'List project secrets.',
          resolver: ::Resolvers::SecretsManagement::ProjectSecretsResolver

        field :project_secret, ::Types::SecretsManagement::ProjectSecretType,
          null: true,
          experiment: { milestone: '17.9' },
          description: 'View a specific project secret.',
          resolver: ::Resolvers::SecretsManagement::ProjectSecretViewResolver

        field :secret_permissions, ::Types::SecretsManagement::Permissions::SecretPermissionType.connection_type,
          null: true,
          experiment: { milestone: '17.10' },
          description: 'List secret permissions.',
          resolver: ::Resolvers::SecretsManagement::Permissions::SecretPermissionsResolver

        field :ai_feature_settings,
          ::Types::Ai::FeatureSettings::FeatureSettingType.connection_type,
          null: true,
          description: 'List of configurable AI features.',
          resolver: ::Resolvers::Ai::FeatureSettings::FeatureSettingsResolver,
          experiment: { milestone: '17.4' }

        field :ai_slash_commands, [::Types::Ai::SlashCommandType], null: true,
          resolver: ::Resolvers::Ai::SlashCommandsResolver,
          description: 'Get available GitLab Duo Chat slash commands for the current user for a specific URL'

        field :ai_chat_context_presets, ::Types::Ai::Chat::ContextPresetsType, null: true,
          resolver: ::Resolvers::Ai::Chat::ContextPresetsResolver,
          calls_gitaly: true,
          description: 'Get available GitLab Duo Chat context presets for the current user for a specific URL'

        field :compliance_requirement_controls, ::Types::ComplianceManagement::ComplianceRequirementControlType,
          null: true,
          fallback_value: [],
          description: 'Get the list of all the compliance requirement controls.'

        field :duo_settings, ::Types::Ai::DuoSettings::DuoSettingsType,
          null: true,
          fallback_value: {},
          description: 'Get GitLab Duo settings',
          resolver: ::Resolvers::Ai::DuoSettings::DuoSettingsResolver,
          experiment: { milestone: '17.9' }

        field :custom_field, ::Types::Issuables::CustomFieldType,
          null: true,
          description: 'Find a custom field by its ID.',
          resolver: ::Resolvers::Issuables::CustomFieldResolver,
          experiment: { milestone: '17.10' }

        field :ldap_admin_role_links,
          ::Types::Authz::LdapAdminRoleLinkType.connection_type,
          description: 'LDAP admin links. Available only for GitLab Self-Managed.',
          resolver: ::Resolvers::Authz::LdapAdminRoleLinksResolver,
          experiment: { milestone: '17.11' }

        field :ai_model_selection_namespace_settings,
          ::Types::Ai::ModelSelection::Namespaces::FeatureSettingType.connection_type,
          null: true,
          description: 'List of configurable AI features for namespace Model Selection.',
          resolver: ::Resolvers::Ai::ModelSelection::Namespaces::FeatureSettingsResolver,
          experiment: { milestone: '18.1' }

        field :project_compliance_violation,
          ::Types::ComplianceManagement::Projects::ComplianceViolationType,
          null: true,
          description: "Find a project compliance violation." do
          argument :id, ::Types::GlobalIDType[::ComplianceManagement::Projects::ComplianceViolation],
            required: true,
            description: 'Global ID of the project compliance violation.'
        end
      end

      def vulnerability(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def dependency(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def iteration(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def workspace(id:)
        unless License.feature_available?(:remote_development)
          # NOTE: Could have `included Gitlab::Graphql::Authorize::AuthorizeResource` and then use
          #       raise_resource_not_available_error!, but didn't want to take the risk to mix that into
          #       the root query type
          # rubocop:disable Graphql/ResourceNotAvailableError -- intentionally not used - see note above
          raise ::Gitlab::Graphql::Errors::ResourceNotAvailable,
            "'remote_development' licensed feature is not available"
          # rubocop:enable Graphql/ResourceNotAvailableError
        end

        ::GitlabSchema.find_by_gid(id)
      end

      def ci_minutes_usage(namespace_id: nil, date: nil)
        root_namespace = find_root_namespace(namespace_id)
        if date
          ::Ci::Minutes::NamespaceMonthlyUsage.by_namespace_and_date(root_namespace, date)
        else
          ::Ci::Minutes::NamespaceMonthlyUsage.for_namespace(root_namespace)
        end
      end

      def member_role_permissions
        get_enabled_permissions(MemberRole.all_customizable_standard_permissions.keys)
      end

      def admin_member_role_permissions
        get_enabled_permissions(MemberRole.all_customizable_admin_permission_keys)
      end

      def project_compliance_violation(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def ai_catalog_built_in_tools
        return [] unless ::Feature.enabled?(:global_ai_catalog, current_user)

        ::Ai::Catalog::BuiltInTool.all
      end

      private

      def get_enabled_permissions(permission_keys)
        permission_keys.select { |key| ::MemberRole.permission_enabled?(key, current_user) }
      end

      def find_root_namespace(namespace_id)
        return current_user&.namespace unless namespace_id

        namespace = ::Gitlab::Graphql::Lazy.force(::GitlabSchema.find_by_gid(namespace_id))
        return unless namespace&.root?

        namespace
      end
    end
  end
end
