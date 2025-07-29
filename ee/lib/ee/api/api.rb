# frozen_string_literal: true

module EE
  module API
    module API
      extend ActiveSupport::Concern

      prepended do
        mount ::EE::API::GroupBoards

        mount ::API::AdminMemberRoles
        mount ::API::Admin::Search::Zoekt
        mount ::API::Admin::Search::Migrations
        mount ::API::Admin::Security::CompliancePolicySettings
        mount ::API::AuditEvents
        mount ::API::Clusters::AgentUrlConfigurations
        mount ::API::ProjectApprovalRules
        mount ::API::ProjectSecuritySettings
        mount ::API::GroupSecuritySettings
        mount ::API::GroupApprovalRules
        mount ::API::StatusChecks
        mount ::API::ProjectApprovalSettings
        mount ::API::Dora::Metrics
        mount ::API::EpicIssues
        mount ::API::EpicLinks
        mount ::API::Epics
        mount ::API::EpicBoards
        mount ::API::DependencyProxy::Packages::Maven
        mount ::API::DependencyProxy::Packages::Npm
        mount ::API::RelatedEpicLinks
        mount ::API::ElasticsearchIndexedNamespaces
        mount ::API::Experiments
        mount ::API::GeoNodes
        mount ::API::GeoSites
        mount ::API::Ldap
        mount ::API::LdapGroupLinks
        mount ::API::License
        mount ::API::ProjectMirror
        mount ::API::ProjectPushRule
        mount ::API::GroupPushRule
        mount ::API::MergeTrains
        mount ::API::MemberRoles
        mount ::API::ProviderIdentity
        mount ::API::GroupHooks
        mount ::API::MergeRequestApprovalSettings
        mount ::API::MergeRequestDependencies
        mount ::API::Scim::GroupScim
        mount ::API::Scim::InstanceScim
        mount ::API::Manage::Groups
        mount ::API::ServiceAccounts
        mount ::API::ManagedLicenses
        mount ::API::ProjectApprovals
        mount ::API::ProjectGoogleCloudIntegration
        mount ::API::Vulnerabilities
        mount ::API::VulnerabilityFindings
        mount ::API::VulnerabilityIssueLinks
        mount ::API::VulnerabilityArchiveExports
        mount ::API::VulnerabilityExports
        mount ::API::MergeRequestApprovalRules
        mount ::API::ProjectAliases
        mount ::API::Dependencies
        mount ::API::Analytics::CodeReviewAnalytics
        mount ::API::Analytics::GroupActivityAnalytics
        mount ::API::Analytics::ProductAnalytics
        mount ::API::Analytics::ProjectDeploymentFrequency
        mount ::API::ProtectedEnvironments
        mount ::API::ResourceWeightEvents
        mount ::API::ResourceIterationEvents
        mount ::API::SamlGroupLinks
        mount ::API::Sbom::Occurrences
        mount ::API::Iterations
        mount ::API::GroupRepositoryStorageMoves
        mount ::API::GroupProtectedBranches
        mount ::API::DependencyListExports
        mount ::API::GroupServiceAccounts
        mount ::API::GroupEnterpriseUsers
        mount ::API::Ai::Llm::GitCommand
        mount ::API::Ai::DuoWorkflows::Workflows
        mount ::API::Ai::DuoWorkflows::WorkflowsInternal
        mount ::API::CodeSuggestions
        mount ::API::Chat
        mount ::API::DuoCodeReview
        mount ::API::SecurityScans
        mount ::API::ComplianceExternalControls
        mount ::API::VirtualRegistries::Packages::Maven::Registries
        mount ::API::VirtualRegistries::Packages::Maven::Upstreams
        mount ::API::VirtualRegistries::Packages::Maven::RegistryUpstreams
        mount ::API::VirtualRegistries::Packages::Maven::Cache::Entries
        mount ::API::VirtualRegistries::Packages::Maven::Endpoints

        mount ::API::Internal::AppSec::Dast::SiteValidations
        mount ::API::Internal::Search::Zoekt
        mount ::API::Internal::SuggestedReviewers
        mount ::API::Internal::Ai::XRay::Scan
        mount ::API::Internal::Observability

        mount ::GitlabSubscriptions::API::Internal::API
      end
    end
  end
end
