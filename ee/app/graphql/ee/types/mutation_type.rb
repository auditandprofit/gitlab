# frozen_string_literal: true

module EE
  module Types
    module MutationType
      extend ActiveSupport::Concern

      prepended do
        def self.authorization_scopes
          super + [:ai_features, :ai_workflows]
        end

        mount_mutation ::Mutations::Ai::Catalog::Agent::Create, experiment: { milestone: '18.2' }
        mount_mutation ::Mutations::Ai::Catalog::Agent::Delete, experiment: { milestone: '18.2' }
        mount_mutation ::Mutations::Ai::Catalog::Agent::Update, experiment: { milestone: '18.3' }
        mount_mutation ::Mutations::Ai::Catalog::Flow::Create, experiment: { milestone: '18.3' }
        mount_mutation ::Mutations::Ai::Catalog::Flow::Delete, experiment: { milestone: '18.3' }
        mount_mutation ::Mutations::Ai::Catalog::Flow::Update, experiment: { milestone: '18.3' }
        mount_mutation ::Mutations::Ai::Catalog::ItemConsumer::Create, experiment: { milestone: '18.3' }
        mount_mutation ::Mutations::Ai::Catalog::ItemConsumer::Delete, experiment: { milestone: '18.3' }
        mount_mutation ::Mutations::Ai::Catalog::ItemConsumer::Update, experiment: { milestone: '18.3' }
        mount_mutation ::Mutations::Ci::Catalog::VerifiedNamespace::Create
        mount_mutation ::Mutations::Ci::ProjectSubscriptions::Create
        mount_mutation ::Mutations::Ci::ProjectSubscriptions::Delete
        mount_mutation ::Mutations::Clusters::AgentUrlConfigurations::Create
        mount_mutation ::Mutations::Clusters::AgentUrlConfigurations::Delete
        mount_mutation ::Mutations::ComplianceManagement::Frameworks::Destroy
        mount_mutation ::Mutations::ComplianceManagement::Frameworks::Update
        mount_mutation ::Mutations::ComplianceManagement::Frameworks::Create
        mount_mutation ::Mutations::Issuables::CustomFields::Create, experiment: { milestone: '17.6' }
        mount_mutation ::Mutations::Issuables::CustomFields::Update, experiment: { milestone: '17.6' }
        mount_mutation ::Mutations::Issuables::CustomFields::Archive, experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::Issuables::CustomFields::Unarchive, experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::Issues::SetIteration
        mount_mutation ::Mutations::Issues::SetWeight
        mount_mutation ::Mutations::Issues::SetEpic,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Issues::SetEscalationPolicy
        mount_mutation ::Mutations::Issues::PromoteToEpic,
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }
        mount_mutation ::Mutations::EpicTree::Reorder,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Epics::Update,
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }
        mount_mutation ::Mutations::Epics::Create,
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }
        mount_mutation ::Mutations::Epics::SetSubscription,
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }
        mount_mutation ::Mutations::Epics::AddIssue,
          deprecated: {
            reason: 'Replaced by `WorkItem` type. For more information, see [migration guide](https://docs.gitlab.com/api/graphql/epic_work_items_api_migration_guide/)',
            milestone: '17.5'
          }
        mount_mutation ::Mutations::Geo::Registries::Update, experiment: { milestone: '16.1' }
        mount_mutation ::Mutations::Geo::Registries::BulkUpdate, experiment: { milestone: '16.4' }
        mount_mutation ::Mutations::GitlabSubscriptions::Activate
        mount_mutation ::Mutations::GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionRequest,
          experiment: { milestone: '17.2' }
        mount_mutation ::Mutations::GitlabSubscriptions::UserAddOnAssignments::Create
        mount_mutation ::Mutations::GitlabSubscriptions::UserAddOnAssignments::Remove
        mount_mutation ::Mutations::GitlabSubscriptions::UserAddOnAssignments::BulkCreate
        mount_mutation ::Mutations::GitlabSubscriptions::UserAddOnAssignments::BulkRemove
        mount_mutation ::Mutations::Projects::SetLocked
        mount_mutation ::Mutations::Iterations::Create
        mount_mutation ::Mutations::Iterations::Update
        mount_mutation ::Mutations::Iterations::Delete
        mount_mutation ::Mutations::Iterations::Cadences::Create
        mount_mutation ::Mutations::Iterations::Cadences::Update
        mount_mutation ::Mutations::Iterations::Cadences::Destroy
        mount_mutation ::Mutations::MemberRoles::Update
        mount_mutation ::Mutations::MemberRoles::Create, experiment: { milestone: '16.5' }
        mount_mutation ::Mutations::MemberRoles::Admin::Create, experiment: { milestone: '17.7' }
        mount_mutation ::Mutations::MemberRoles::Admin::Update, experiment: { milestone: '17.10' }
        mount_mutation ::Mutations::MemberRoles::Admin::Delete, experiment: { milestone: '17.10' }
        mount_mutation ::Mutations::MemberRoles::Delete, experiment: { milestone: '16.7' }
        mount_mutation ::Mutations::RequirementsManagement::CreateRequirement
        mount_mutation ::Mutations::RequirementsManagement::ExportRequirements
        mount_mutation ::Mutations::RequirementsManagement::UpdateRequirement
        mount_mutation ::Mutations::SecretsManagement::ProjectSecretsManagers::Initialize
        mount_mutation ::Mutations::SecretsManagement::ProjectSecrets::Create
        mount_mutation ::Mutations::SecretsManagement::ProjectSecrets::Delete
        mount_mutation ::Mutations::SecretsManagement::ProjectSecrets::Update
        mount_mutation ::Mutations::SecretsManagement::Permissions::Update
        mount_mutation ::Mutations::SecretsManagement::Permissions::Delete
        mount_mutation ::Mutations::Security::Finding::CreateIssue
        mount_mutation ::Mutations::Security::Finding::CreateMergeRequest
        mount_mutation ::Mutations::Security::Finding::CreateVulnerability, experiment: { milestone: '17.5' }
        mount_mutation ::Mutations::Security::Finding::Dismiss
        mount_mutation ::Mutations::Security::Finding::RefreshFindingTokenStatus
        mount_mutation ::Mutations::Security::Finding::RevertToDetected
        mount_mutation ::Mutations::Security::Finding::SeverityOverride
        mount_mutation ::Mutations::Vulnerabilities::Archival::Archive, experiment: { milestone: '17.10' }
        mount_mutation ::Mutations::Vulnerabilities::Create
        mount_mutation ::Mutations::Vulnerabilities::BulkDismiss
        mount_mutation ::Mutations::Vulnerabilities::RemoveAllFromProject
        mount_mutation ::Mutations::Vulnerabilities::Dismiss, scopes: [:api, :read_api, :ai_workflows]
        mount_mutation ::Mutations::Vulnerabilities::Resolve
        mount_mutation ::Mutations::Vulnerabilities::Confirm
        mount_mutation ::Mutations::Vulnerabilities::RevertToDetected
        mount_mutation ::Mutations::Vulnerabilities::CreateIssueLink
        mount_mutation ::Mutations::Vulnerabilities::CreateExternalIssueLink
        mount_mutation ::Mutations::Vulnerabilities::DestroyExternalIssueLink
        mount_mutation ::Mutations::Vulnerabilities::BulkSeverityOverride
        mount_mutation ::Mutations::Vulnerabilities::CreateIssue, experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::Boards::UpdateEpicUserPreferences,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::EpicBoards::Create,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::EpicBoards::Destroy,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::EpicBoards::EpicMoveList,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::EpicBoards::Update,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::EpicLists::Create,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::EpicLists::Destroy,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::EpicLists::Update,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::Epics::Create,
          deprecated: { reason: 'Replaced by WorkItem type', milestone: '17.5' }
        mount_mutation ::Mutations::Boards::Lists::UpdateLimitMetrics
        mount_mutation ::Mutations::BranchRules::ExternalStatusChecks::Create, experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::BranchRules::ExternalStatusChecks::Update, experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::BranchRules::ExternalStatusChecks::Destroy, experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::Projects::BranchRules::SquashOptions::Delete, experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::InstanceSecurityDashboard::AddProject
        mount_mutation ::Mutations::InstanceSecurityDashboard::RemoveProject
        mount_mutation ::Mutations::DastOnDemandScans::Create
        mount_mutation ::Mutations::Dast::Profiles::Create
        mount_mutation ::Mutations::Dast::Profiles::Update
        mount_mutation ::Mutations::Dast::Profiles::Delete
        mount_mutation ::Mutations::Dast::Profiles::Run
        mount_mutation ::Mutations::DastSiteProfiles::Create
        mount_mutation ::Mutations::DastSiteProfiles::Update
        mount_mutation ::Mutations::DastSiteProfiles::Delete
        mount_mutation ::Mutations::DastSiteValidations::Create
        mount_mutation ::Mutations::DastSiteValidations::Revoke
        mount_mutation ::Mutations::DastScannerProfiles::Create
        mount_mutation ::Mutations::DastScannerProfiles::Update
        mount_mutation ::Mutations::DastScannerProfiles::Delete
        mount_mutation ::Mutations::DastSiteTokens::Create
        mount_mutation ::Mutations::QualityManagement::TestCases::Create
        mount_mutation ::Mutations::Analytics::DevopsAdoption::EnabledNamespaces::Enable
        mount_mutation ::Mutations::Analytics::DevopsAdoption::EnabledNamespaces::BulkEnable
        mount_mutation ::Mutations::Analytics::DevopsAdoption::EnabledNamespaces::Disable
        mount_mutation ::Mutations::IncidentManagement::OncallSchedule::Create
        mount_mutation ::Mutations::IncidentManagement::OncallSchedule::Update
        mount_mutation ::Mutations::IncidentManagement::OncallSchedule::Destroy
        mount_mutation ::Mutations::IncidentManagement::OncallRotation::Create
        mount_mutation ::Mutations::IncidentManagement::OncallRotation::Update
        mount_mutation ::Mutations::IncidentManagement::OncallRotation::Destroy
        mount_mutation ::Mutations::IncidentManagement::EscalationPolicy::Create
        mount_mutation ::Mutations::IncidentManagement::EscalationPolicy::Update
        mount_mutation ::Mutations::IncidentManagement::EscalationPolicy::Destroy
        mount_mutation ::Mutations::IncidentManagement::IssuableResourceLink::Create
        mount_mutation ::Mutations::IncidentManagement::IssuableResourceLink::Destroy
        mount_mutation ::Mutations::AppSec::Fuzzing::Coverage::Corpus::Create
        mount_mutation ::Mutations::Projects::SetComplianceFramework,
          deprecated: { reason: 'Use mutation ProjectUpdateComplianceFrameworks instead of this', milestone: '17.11' }
        mount_mutation ::Mutations::Projects::ProjectSettingsUpdate, experiment: { milestone: '16.9' }
        mount_mutation ::Mutations::Projects::InitializeProductAnalytics
        mount_mutation ::Mutations::Projects::ProductAnalyticsProjectSettingsUpdate
        mount_mutation ::Mutations::SecurityPolicy::CommitScanExecutionPolicy
        mount_mutation ::Mutations::SecurityPolicy::AssignSecurityPolicyProject
        mount_mutation ::Mutations::SecurityPolicy::UnassignSecurityPolicyProject
        mount_mutation ::Mutations::SecurityPolicy::CreateSecurityPolicyProject
        mount_mutation ::Mutations::SecurityPolicy::CreateSecurityPolicyProjectAsync, experiment: { milestone: '17.3' }
        mount_mutation ::Mutations::SecurityPolicy::ResyncSecurityPolicies, experiment: { milestone: '18.1' }
        mount_mutation ::Mutations::Security::CiConfiguration::ConfigureDependencyScanning
        mount_mutation ::Mutations::Security::CiConfiguration::ConfigureContainerScanning
        mount_mutation ::Mutations::Security::TrainingProviderUpdate
        mount_mutation ::Mutations::Security::ProjectSecurityExclusionCreate
        mount_mutation ::Mutations::Security::ProjectSecurityExclusionUpdate
        mount_mutation ::Mutations::Security::ProjectSecurityExclusionDelete
        mount_mutation ::Mutations::Users::Abuse::NamespaceBans::Destroy
        mount_mutation ::Mutations::Users::MemberRoles::Assign, experiment: { milestone: '17.7' }
        mount_mutation ::Mutations::AuditEvents::ExternalAuditEventDestinations::Create
        mount_mutation ::Mutations::AuditEvents::ExternalAuditEventDestinations::Destroy
        mount_mutation ::Mutations::AuditEvents::ExternalAuditEventDestinations::Update
        mount_mutation ::Mutations::Ci::NamespaceCiCdSettingsUpdate
        mount_mutation ::Mutations::Ci::Runners::ExportUsage
        mount_mutation ::Mutations::RemoteDevelopment::WorkspaceOperations::Create
        mount_mutation ::Mutations::RemoteDevelopment::WorkspaceOperations::Update
        mount_mutation ::Mutations::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Create
        mount_mutation ::Mutations::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Delete
        mount_mutation ::Mutations::RemoteDevelopment::OrganizationClusterAgentMappingOperations::Create, experiment: {
          milestone: '17.11'
        }
        mount_mutation ::Mutations::RemoteDevelopment::OrganizationClusterAgentMappingOperations::Delete, experiment: {
          milestone: '17.11'
        }
        mount_mutation ::Mutations::AuditEvents::Streaming::Headers::Destroy
        mount_mutation ::Mutations::AuditEvents::Streaming::Headers::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::Headers::Update
        mount_mutation ::Mutations::AuditEvents::Streaming::EventTypeFilters::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::EventTypeFilters::Destroy
        mount_mutation ::Mutations::Deployments::DeploymentApprove
        mount_mutation ::Mutations::MergeRequests::UpdateApprovalRule
        mount_mutation ::Mutations::MergeRequests::DestroyRequestedChanges
        mount_mutation ::Mutations::Ai::Action, experiment: { milestone: '15.11' }, scopes: [:api, :ai_features]
        mount_mutation ::Mutations::Ai::DuoUserFeedback, experiment: {
          milestone: '16.10'
        }, scopes: [:api, :ai_features]
        mount_mutation ::Mutations::AuditEvents::InstanceExternalAuditEventDestinations::Create
        mount_mutation ::Mutations::AuditEvents::InstanceExternalAuditEventDestinations::Destroy
        mount_mutation ::Mutations::AuditEvents::InstanceExternalAuditEventDestinations::Update
        mount_mutation ::Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Create
        mount_mutation ::Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Destroy
        mount_mutation ::Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Update
        mount_mutation ::Mutations::AuditEvents::AmazonS3Configurations::Create
        mount_mutation ::Mutations::AuditEvents::AmazonS3Configurations::Delete
        mount_mutation ::Mutations::AuditEvents::AmazonS3Configurations::Update
        mount_mutation ::Mutations::AuditEvents::Instance::AmazonS3Configurations::Create
        mount_mutation ::Mutations::AuditEvents::Instance::AmazonS3Configurations::Delete
        mount_mutation ::Mutations::AuditEvents::Instance::AmazonS3Configurations::Update
        mount_mutation ::Mutations::AuditEvents::Instance::GoogleCloudLoggingConfigurations::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceHeaders::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceHeaders::Update
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceHeaders::Destroy
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceEventTypeFilters::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceEventTypeFilters::Destroy
        mount_mutation ::Mutations::Security::CiConfiguration::ProjectSetContinuousVulnerabilityScanning, deprecated: {
          milestone: '17.3',
          reason: 'CVS has been enabled permanently. See [this ' \
            'epic](https://gitlab.com/groups/gitlab-org/-/epics/11474) for more information'
        }
        mount_mutation ::Mutations::Security::CiConfiguration::SetSecretPushProtection
        mount_mutation ::Mutations::Security::CiConfiguration::SetPreReceiveSecretDetection
        mount_mutation ::Mutations::Security::CiConfiguration::SetGroupSecretPushProtection
        mount_mutation ::Mutations::Security::CiConfiguration::SetValidityChecks
        mount_mutation ::Mutations::Security::CiConfiguration::SetContainerScanningForRegistry
        mount_mutation ::Mutations::AuditEvents::Instance::GoogleCloudLoggingConfigurations::Destroy
        mount_mutation ::Mutations::AuditEvents::Instance::GoogleCloudLoggingConfigurations::Update
        mount_mutation ::Mutations::DependencyProxy::Packages::Settings::Update
        mount_mutation ::Mutations::Analytics::CycleAnalytics::ValueStreams::Create, experiment: { milestone: '16.6' }
        mount_mutation ::Mutations::Analytics::CycleAnalytics::ValueStreams::Update, experiment: { milestone: '16.6' }
        mount_mutation ::Mutations::Analytics::CycleAnalytics::ValueStreams::Destroy, experiment: { milestone: '16.6' }
        mount_mutation ::Mutations::AuditEvents::Streaming::HTTP::NamespaceFilters::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::HTTP::NamespaceFilters::Delete
        mount_mutation ::Mutations::Ai::Agents::Create, experiment: { milestone: '16.8' }
        mount_mutation ::Mutations::Ai::Agents::Update, experiment: { milestone: '16.10' }
        mount_mutation ::Mutations::Ai::Agents::Destroy, experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::ComplianceManagement::Standards::RefreshAdherenceChecks
        mount_mutation ::Mutations::Groups::SavedReplies::Create, experiment: { milestone: '16.10' }
        mount_mutation ::Mutations::Groups::SavedReplies::Update, experiment: { milestone: '16.10' }
        mount_mutation ::Mutations::Groups::SavedReplies::Destroy, experiment: { milestone: '16.10' }
        mount_mutation ::Mutations::Members::Groups::Export, experiment: { milestone: '17.4' }
        mount_mutation ::Mutations::Projects::SavedReplies::Create, experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::Projects::SavedReplies::Update, experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::Projects::SavedReplies::Destroy, experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::BranchRules::ApprovalProjectRules::Create, experiment: { milestone: '16.10' }
        mount_mutation ::Mutations::ApprovalProjectRules::Update, experiment: { milestone: '16.10' }
        mount_mutation ::Mutations::ApprovalProjectRules::Delete, experiment: { milestone: '16.10' }
        mount_mutation ::Mutations::AuditEvents::Group::AuditEventStreamingDestinations::Create,
          experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::AuditEvents::Group::AuditEventStreamingDestinations::Delete,
          experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::AuditEvents::Group::AuditEventStreamingDestinations::Update,
          experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Create,
          experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Delete,
          experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update,
          experiment: { milestone: '16.11' }
        mount_mutation ::Mutations::AuditEvents::Group::EventTypeFilters::Create,
          experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::AuditEvents::Group::EventTypeFilters::Delete,
          experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::AuditEvents::Instance::EventTypeFilters::Create,
          experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::AuditEvents::Instance::EventTypeFilters::Delete,
          experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::AuditEvents::Group::NamespaceFilters::Create,
          experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::AuditEvents::Group::NamespaceFilters::Delete,
          experiment: { milestone: '17.0' }
        mount_mutation ::Mutations::Ai::SelfHostedModels::Create,
          experiment: { milestone: '17.1' }
        mount_mutation ::Mutations::AuditEvents::Instance::NamespaceFilters::Create,
          experiment: { milestone: '17.2' }
        mount_mutation ::Mutations::AuditEvents::Instance::NamespaceFilters::Delete,
          experiment: { milestone: '17.2' }
        mount_mutation ::Mutations::Ai::SelfHostedModels::Update,
          experiment: { milestone: '17.2' }
        mount_mutation ::Mutations::Ai::SelfHostedModels::Delete,
          experiment: { milestone: '17.2' }
        mount_mutation ::Mutations::MergeTrains::Cars::Delete, experiment: { milestone: '17.2' }
        mount_mutation ::Mutations::Projects::UpdateComplianceFrameworks
        mount_mutation ::Mutations::Ai::FeatureSettings::Update, experiment: { milestone: '17.4' }
        mount_mutation ::Mutations::Projects::TargetBranchRules::Create
        mount_mutation ::Mutations::Projects::TargetBranchRules::Destroy
        mount_mutation ::Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirements::Create,
          experiment: { milestone: '17.6' }
        mount_mutation ::Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirements::Destroy,
          experiment: { milestone: '17.7' }
        mount_mutation ::Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirements::Update,
          experiment: { milestone: '17.7' }
        mount_mutation ::Mutations::Ai::SelfHostedModels::ConnectionCheck,
          experiment: { milestone: '17.7' }
        mount_mutation ::Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::Create,
          experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::Update,
          experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::Destroy,
          experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::Ai::DuoSettings::Update, experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::Ai::DeleteConversationThread, experiment: { milestone: '17.9' }
        mount_mutation ::Mutations::Ai::DuoWorkflows::DeleteWorkflow, experiment: { milestone: '18.1' }
        mount_mutation ::Mutations::Ai::DuoWorkflows::Create, experiment: { milestone: '18.1' },
          scopes: [:api, :ai_features]
        mount_mutation ::Mutations::Authz::LdapAdminRoleLinks::Create, experiment: { milestone: '17.11' }
        mount_mutation ::Mutations::Authz::LdapAdminRoleLinks::Destroy, experiment: { milestone: '18.0' }
        mount_mutation ::Mutations::Authz::AdminRoles::LdapSync, experiment: { milestone: '18.0' }
        mount_mutation ::Mutations::Ai::ModelSelection::Namespaces::Update, experiment: { milestone: '18.1' }
        mount_mutation ::Mutations::WorkItems::Lifecycles::Update, experiment: { milestone: '18.1' }
        mount_mutation ::Mutations::VirtualRegistries::Packages::Maven::MavenUpstreamCreateMutation,
          experiment: { milestone: '18.2' }
        mount_mutation ::Mutations::ComplianceManagement::Projects::ComplianceViolations::Update,
          experiment: { milestone: '18.2' }
        mount_mutation ::Mutations::ComplianceManagement::Projects::ComplianceViolations::LinkIssue, experiment: {
          milestone: '18.3'
        }
        mount_mutation ::Mutations::ComplianceManagement::Projects::ComplianceViolations::UnlinkIssue,
          experiment: { milestone: '18.3' }

        prepend(Types::DeprecatedMutations)
      end
    end
  end
end
