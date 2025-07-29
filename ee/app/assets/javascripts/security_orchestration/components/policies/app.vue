<script>
import { groupBy } from 'lodash';
import { s__ } from '~/locale';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { createAlert } from '~/alert';
import { getParameterByName } from '~/lib/utils/url_utility';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  exceedsActionLimit,
  exceedsScheduleRulesLimit,
  extractSourceParameter,
  extractTypeParameter,
} from 'ee/security_orchestration/components/policies/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { isGroup } from '../utils';
import projectScanExecutionPoliciesQuery from '../../graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from '../../graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from '../../graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from '../../graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from '../../graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from '../../graphql/queries/group_pipeline_execution_policies.query.graphql';
import projectPipelineExecutionSchedulePoliciesQuery from '../../graphql/queries/project_pipeline_execution_schedule_policies.query.graphql';
import groupPipelineExecutionSchedulePoliciesQuery from '../../graphql/queries/group_pipeline_execution_schedule_policies.query.graphql';
import projectVulnerabilityManagementPoliciesQuery from '../../graphql/queries/project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPoliciesQuery from '../../graphql/queries/group_vulnerability_management_policies.query.graphql';
import ListHeader from './list_header.vue';
import ListComponent from './list_component.vue';
import {
  DEPRECATED_CUSTOM_SCAN_PROPERTY,
  POLICY_TYPE_FILTER_OPTIONS,
  ACTION_LIMIT,
  POLICIES_PER_PAGE,
  PIPELINE_TYPE_COMBINED_TYPE_MAP,
} from './constants';

const NAMESPACE_QUERY_DICT = {
  scanExecution: {
    [NAMESPACE_TYPES.PROJECT]: projectScanExecutionPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanExecutionPoliciesQuery,
  },
  scanResult: {
    [NAMESPACE_TYPES.PROJECT]: projectScanResultPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanResultPoliciesQuery,
  },
  pipelineExecution: {
    [NAMESPACE_TYPES.PROJECT]: projectPipelineExecutionPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupPipelineExecutionPoliciesQuery,
  },
  pipelineExecutionSchedule: {
    [NAMESPACE_TYPES.PROJECT]: projectPipelineExecutionSchedulePoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupPipelineExecutionSchedulePoliciesQuery,
  },
  vulnerabilityManagement: {
    [NAMESPACE_TYPES.PROJECT]: projectVulnerabilityManagementPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupVulnerabilityManagementPoliciesQuery,
  },
};

const NAMESPACE_QUERY_DICT_COMBINED_LIST = {
  [NAMESPACE_TYPES.PROJECT]: projectSecurityPoliciesQuery,
  [NAMESPACE_TYPES.GROUP]: groupSecurityPoliciesQuery,
};

const createPolicyFetchError = ({ gqlError, networkError }) => {
  const error =
    gqlError?.message ||
    networkError?.message ||
    s__('SecurityOrchestration|Something went wrong, unable to fetch policies');
  createAlert({
    message: error,
  });
};

export default {
  components: {
    ListHeader,
    ListComponent,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'assignedPolicyProject',
    'enabledExperiments',
    'namespacePath',
    'namespaceType',
    'maxScanExecutionPolicyActions',
    'maxScanExecutionPolicySchedules',
  ],
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const {
          securityPolicyProjectLinkedProjects: { nodes: linkedProjects = [] } = {},
          securityPolicyProjectLinkedGroups: { nodes: linkedGroups = [] } = {},
        } = data?.project || {};

        return [...linkedProjects, ...linkedGroups];
      },
      skip() {
        return isGroup(this.namespaceType);
      },
      error: createPolicyFetchError,
    },
    securityPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT_COMBINED_LIST[this.namespaceType];
      },
      variables() {
        return {
          ...this.queryVariables,
          ...(this.type ? { type: this.type } : {}),
        };
      },
      result({ data }) {
        this.pageInfo = data?.namespace?.securityPolicies?.pageInfo ?? {};
      },
      update(data) {
        return data?.namespace?.securityPolicies?.nodes ?? [];
      },
      skip() {
        return !this.hasCombinedList;
      },
      error: createPolicyFetchError,
    },
    scanExecutionPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanExecution[this.namespaceType];
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data?.namespace?.scanExecutionPolicies?.nodes ?? [];
      },
      result({ data }) {
        return data?.namespace?.scanExecutionPolicies?.nodes ?? [];
      },
      skip() {
        return this.hasCombinedList;
      },
      error: createPolicyFetchError,
    },
    scanResultPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanResult[this.namespaceType];
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data?.namespace?.scanResultPolicies?.nodes ?? [];
      },
      result({ data }) {
        return data?.namespace?.scanResultPolicies?.nodes ?? [];
      },
      skip() {
        return this.hasCombinedList;
      },
      error: createPolicyFetchError,
    },
    pipelineExecutionPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.pipelineExecution[this.namespaceType];
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data?.namespace?.pipelineExecutionPolicies?.nodes ?? [];
      },
      skip() {
        return this.hasCombinedList;
      },
      error: createPolicyFetchError,
    },
    pipelineExecutionSchedulePolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.pipelineExecutionSchedule[this.namespaceType];
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data?.namespace?.pipelineExecutionSchedulePolicies?.nodes ?? [];
      },
      skip() {
        return this.hasCombinedList || !this.hasScheduledPoliciesEnabled;
      },
      error: createPolicyFetchError,
    },
    vulnerabilityManagementPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.vulnerabilityManagement[this.namespaceType];
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data?.namespace?.vulnerabilityManagementPolicies?.nodes ?? [];
      },
      skip() {
        return this.hasCombinedList;
      },
      error: createPolicyFetchError,
    },
  },
  data() {
    const selectedPolicySource = extractSourceParameter(getParameterByName('source'));
    const selectedPolicyType = extractTypeParameter(getParameterByName('type'));
    const type = PIPELINE_TYPE_COMBINED_TYPE_MAP[selectedPolicyType] || '';

    return {
      hasPolicyProject: Boolean(this.assignedPolicyProject?.id),
      selectedPolicySource,
      selectedPolicyType,
      shouldUpdatePolicyList: false,
      linkedSppItems: [],
      pipelineExecutionPolicies: [],
      pipelineExecutionSchedulePolicies: [],
      scanExecutionPolicies: [],
      scanResultPolicies: [],
      vulnerabilityManagementPolicies: [],
      pageInfo: {},
      securityPolicies: [],
      type,
    };
  },
  computed: {
    queryVariables() {
      return {
        fullPath: this.namespacePath,
        relationship: this.selectedPolicySource,
      };
    },
    hasExceedingScheduledLimitPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]?.some(
        ({ yaml }) =>
          exceedsScheduleRulesLimit({
            policyType: POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
            yaml,
            maxScanExecutionPolicySchedules: this.maxScanExecutionPolicySchedules,
          }),
      );
    },
    hasDeprecatedCustomScanPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]?.some((policy) =>
        policy.deprecatedProperties.includes(DEPRECATED_CUSTOM_SCAN_PROPERTY),
      );
    },
    hasExceedingActionLimitPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]?.some(
        ({ yaml }) =>
          exceedsActionLimit({
            policyType: POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
            yaml,
            maxScanExecutionPolicyActions: ACTION_LIMIT,
          }),
      );
    },
    hasInvalidPolicies() {
      return this.policiesByType[POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]?.some((policy) =>
        policy.deprecatedProperties?.some((prop) => prop !== 'scan_result_policy'),
      );
    },
    hasCombinedList() {
      return Boolean(this.glFeatures.securityPoliciesCombinedList);
    },
    hasScheduledPoliciesEnabled() {
      return (
        this.enabledExperiments.includes('pipeline_execution_schedule_policy') &&
        this.glFeatures.scheduledPipelineExecutionPolicies
      );
    },
    flattenedPolicies() {
      return (
        this.securityPolicies?.map(({ policyAttributes = {}, ...policy }) => ({
          ...policy,
          ...policyAttributes,
        })) || []
      );
    },
    policiesByTypeCombinedList() {
      const groupedPolicies = groupBy(this.flattenedPolicies, 'type');

      const policiesByType = {
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]:
          groupedPolicies[POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter] || [],
        [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]:
          groupedPolicies[POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter] || [],
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
          groupedPolicies[POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter] || [],
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
          groupedPolicies[POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.urlParameter] ||
          [],
        [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
          groupedPolicies[POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.urlParameter] || [],
      };

      if (this.hasScheduledPoliciesEnabled) {
        return {
          ...policiesByType,
          [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
            groupedPolicies[POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.urlParameter] ||
            [],
        };
      }

      return policiesByType;
    },
    policiesByTypeMultipleLists() {
      return {
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: this.scanExecutionPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: this.scanResultPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]: this.pipelineExecutionPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
          this.pipelineExecutionSchedulePolicies,
        [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
          this.vulnerabilityManagementPolicies,
      };
    },
    policiesByType() {
      return this.hasCombinedList
        ? this.policiesByTypeCombinedList
        : this.policiesByTypeMultipleLists;
    },
    isLoadingPolicies() {
      if (this.hasCombinedList) {
        return this.$apollo.queries.securityPolicies.loading;
      }

      return (
        this.$apollo.queries.scanExecutionPolicies.loading ||
        this.$apollo.queries.scanResultPolicies.loading ||
        this.$apollo.queries.pipelineExecutionPolicies.loading ||
        this.$apollo.queries.pipelineExecutionSchedulePolicies.loading ||
        this.$apollo.queries.vulnerabilityManagementPolicies.loading
      );
    },
  },
  methods: {
    handleClearedSelected() {
      this.shouldUpdatePolicyList = false;
    },
    handleUpdatePolicyList({ hasPolicyProject, shouldUpdatePolicyList = false }) {
      if (hasPolicyProject !== undefined) {
        this.hasPolicyProject = hasPolicyProject;
      }

      this.shouldUpdatePolicyList = shouldUpdatePolicyList;

      if (this.hasCombinedList) {
        this.$apollo.queries.securityPolicies.refetch();
        return;
      }

      this.$apollo.queries.scanExecutionPolicies.refetch();
      this.$apollo.queries.scanResultPolicies.refetch();
      this.$apollo.queries.pipelineExecutionPolicies.refetch();
      this.$apollo.queries.pipelineExecutionSchedulePolicies.refetch();
      this.$apollo.queries.vulnerabilityManagementPolicies.refetch();
    },
    handleUpdatePolicySource(value) {
      this.selectedPolicySource = value;
    },
    async handleUpdatePolicyType(value) {
      if (this.hasCombinedList) {
        this.type = PIPELINE_TYPE_COMBINED_TYPE_MAP[value] || '';
      }

      this.selectedPolicyType = value;
    },
    async handlePageChange(isNext = false) {
      const pageVariables = isNext
        ? { after: this.pageInfo.endCursor }
        : { before: this.pageInfo.startCursor, first: null, last: POLICIES_PER_PAGE };

      try {
        const { data } = await this.$apollo.queries.securityPolicies.fetchMore({
          variables: {
            ...this.queryVariables,
            ...pageVariables,
          },
        });
        const { pageInfo = {}, nodes = [] } = data?.namespace?.securityPolicies ?? {};

        this.pageInfo = pageInfo;
        this.securityPolicies = nodes;
      } catch (e) {
        createPolicyFetchError(e);
      }
    },
  },
};
</script>
<template>
  <div>
    <list-header
      :has-exceeding-scheduled-limit-policies="hasExceedingScheduledLimitPolicies"
      :has-exceeding-action-limit-policies="hasExceedingActionLimitPolicies"
      :has-invalid-policies="hasInvalidPolicies"
      :has-deprecated-custom-scan-policies="hasDeprecatedCustomScanPolicies"
      @update-policy-list="handleUpdatePolicyList"
    />
    <list-component
      :has-policy-project="hasPolicyProject"
      :should-update-policy-list="shouldUpdatePolicyList"
      :is-loading-policies="isLoadingPolicies"
      :selected-policy-source="selectedPolicySource"
      :selected-policy-type="selectedPolicyType"
      :linked-spp-items="linkedSppItems"
      :page-info="pageInfo"
      :policies-by-type="policiesByType"
      @cleared-selected="handleClearedSelected"
      @next-page="handlePageChange(true)"
      @prev-page="handlePageChange(false)"
      @update-policy-source="handleUpdatePolicySource"
      @update-policy-type="handleUpdatePolicyType"
    />
  </div>
</template>
