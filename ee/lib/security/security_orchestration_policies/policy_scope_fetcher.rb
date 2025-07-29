# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PolicyScopeFetcher
      include ::GitlabSubscriptions::SubscriptionHelper

      def initialize(policy_scope:, container:, current_user:)
        @policy_scope = policy_scope
        @container = container
        @current_user = current_user
      end

      def execute
        return result if policy_scope.blank?

        result(compliance_frameworks, scoped_projects, scoped_groups)
      end

      private

      attr_reader :policy_scope, :container, :current_user

      def result(compliance_frameworks = [], scoped_projects = [[], []], scoped_groups = [[], []])
        including_projects, excluding_projects = scoped_projects
        including_groups, excluding_groups = scoped_groups

        {
          compliance_frameworks: compliance_frameworks,
          including_projects: including_projects,
          excluding_projects: excluding_projects,
          including_groups: including_groups,
          excluding_groups: excluding_groups
        }
      end

      def compliance_frameworks
        compliance_framework_ids = policy_scope[:compliance_frameworks]&.pluck(:id)

        return [] if compliance_framework_ids.blank?

        if !gitlab_com_subscription? && root_ancestor.nil?
          ComplianceManagement::Framework.id_in(compliance_framework_ids)
        elsif root_ancestor.present?
          root_ancestor.compliance_management_frameworks.id_in(compliance_framework_ids)
        else
          []
        end
      end

      def scoped_projects
        scoped_resources(:projects, Project)
      end

      def scoped_groups
        scoped_resources(:groups, Group)
      end

      def scoped_resources(resource_type, root_ancestor_resources)
        included_ids = policy_scope.dig(resource_type, :including)&.pluck(:id) || []
        excluded_ids = policy_scope.dig(resource_type, :excluding)&.pluck(:id) || []
        ids = included_ids + excluded_ids

        return [[], []] if ids.empty?

        resources = root_ancestor_resources.id_in(ids).index_by(&:id)
        including_resources = resources.values_at(*included_ids).compact
        excluding_resources = resources.values_at(*excluded_ids).compact

        [including_resources, excluding_resources]
      end

      def root_ancestor
        return if container.nil?

        if container.is_a?(ComplianceManagement::Framework)
          container.namespace
        else
          container.root_ancestor
        end
      end

      def group
        return container if container.is_a?(Namespace)

        container.namespace
      end
    end
  end
end
