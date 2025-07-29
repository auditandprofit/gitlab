<script>
import {
  GlBadge,
  GlButton,
  GlTable,
  GlIcon,
  GlSprintf,
  GlLink,
  GlSkeletonLoader,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { getPolicyType } from 'ee/security_orchestration/utils';
import { i18n } from '../constants';
import namespacePoliciesQuery from '../graphql/namespace_policies.query.graphql';
import complianceFrameworkPoliciesQuery from '../graphql/compliance_frameworks_policies.query.graphql';
import EditSection from './edit_section.vue';

function extractPolicies(policies) {
  return {
    policies: policies.nodes || [],
    hasNextPage: policies.pageInfo.hasNextPage,
    endCursor: policies.pageInfo.endCursor,
  };
}

export default {
  components: {
    DrawerWrapper,
    EditSection,
    GlIcon,
    GlBadge,
    GlButton,
    GlSprintf,
    GlTable,
    GlLink,
    GlSkeletonLoader,
  },
  provide() {
    return {
      namespacePath: this.fullPath,
    };
  },
  inject: ['disableScanPolicyUpdate', 'groupSecurityPoliciesPath'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    graphqlId: {
      type: String,
      required: true,
    },
    count: {
      type: Number,
      required: true,
    },
  },

  data() {
    return {
      selectedPolicy: null,
      rawPolicies: {
        namespaceApprovalPolicies: [],
        namespaceScanExecutionPolicies: [],
        namespacePipelineExecutionPolicies: [],
        namespaceVulnerabilityManagementPolicies: [],
        complianceApprovalPolicies: [],
        complianceScanExecutionPolicies: [],
        compliancePipelineExecutionPolicies: [],
        complianceVulnerabilityManagementPolicies: [],
      },
      policiesLoaded: false,
      namespacePoliciesLoaded: false,
      policiesLoadCursor: {
        namespaceApprovalPoliciesAfter: null,
        namespaceScanExecutionPoliciesAfter: null,
        namespacePipelineExecutionPoliciesAfter: null,
        namespaceVulnerabilityManagementPoliciesAfter: null,
        complianceApprovalPoliciesAfter: null,
        complianceScanExecutionPoliciesAfter: null,
        compliancePipelineExecutionPoliciesAfter: null,
        complianceVulnerabilityManagementPoliciesAfter: null,
      },
      isExpanded: false,
    };
  },

  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    namespacePolicies: {
      query: namespacePoliciesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          approvalPoliciesAfter: this.policiesLoadCursor.namespaceApprovalPoliciesAfter,
          scanExecutionPoliciesAfter: this.policiesLoadCursor.namespaceScanExecutionPoliciesAfter,
          pipelineExecutionPoliciesAfter:
            this.policiesLoadCursor.namespacePipelineExecutionPoliciesAfter,
          vulnerabilityManagementPoliciesAfter:
            this.policiesLoadCursor.namespaceVulnerabilityManagementPoliciesAfter,
        };
      },
      update(data) {
        this.updatePolicies(
          data.namespace,
          {
            approvalField: 'approvalPolicies',
            scanExecutionField: 'scanExecutionPolicies',
            pipelineExecutionField: 'pipelineExecutionPolicies',
            vulnerabilityManagementField: 'vulnerabilityManagementPolicies',
            target: 'namespace',
          },
          'namespacePoliciesLoaded',
        );
      },
      error(error) {
        this.handleError(error);
      },
      skip() {
        return !this.isExpanded || this.namespacePoliciesLoaded;
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    complianceFrameworkPolicies: {
      query: complianceFrameworkPoliciesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          complianceFramework: this.graphqlId,
          approvalPoliciesAfter: this.policiesLoadCursor.complianceApprovalPoliciesAfter,
          scanExecutionPoliciesAfter: this.policiesLoadCursor.complianceScanExecutionPoliciesAfter,
          pipelineExecutionPoliciesAfter:
            this.policiesLoadCursor.compliancePipelineExecutionPoliciesAfter,
          vulnerabilityManagementPoliciesAfter:
            this.policiesLoadCursor.complianceVulnerabilityManagementPoliciesAfter,
        };
      },
      update(data) {
        this.updatePolicies(
          data.namespace.complianceFrameworks.nodes[0],
          {
            approvalField: 'scanResultPolicies',
            scanExecutionField: 'scanExecutionPolicies',
            pipelineExecutionField: 'pipelineExecutionPolicies',
            vulnerabilityManagementField: 'vulnerabilityManagementPolicies',
            target: 'compliance',
          },
          'policiesLoaded',
        );
      },
      error(error) {
        this.handleError(error);
      },
      skip() {
        return !this.isExpanded || this.policiesLoaded;
      },
    },
  },

  computed: {
    policies() {
      const approvalPoliciesSet = new Set(
        this.rawPolicies.complianceApprovalPolicies.map((p) => p.name),
      );
      const scanExecutionPoliciesSet = new Set(
        this.rawPolicies.complianceScanExecutionPolicies.map((p) => p.name),
      );
      const pipelineExecutionPoliciesSet = new Set(
        this.rawPolicies.compliancePipelineExecutionPolicies.map((p) => p.name),
      );
      const vulnerabilityManagementPoliciesSet = new Set(
        this.rawPolicies.complianceVulnerabilityManagementPolicies.map((p) => p.name),
      );

      const mapPolicies = (key, uniqueSet) =>
        this.rawPolicies[key]
          .filter((p) => uniqueSet.has(p.name))
          .map((p) => ({ ...p, isLinked: true }));

      return [
        ...mapPolicies('namespaceApprovalPolicies', approvalPoliciesSet),
        ...mapPolicies('namespaceScanExecutionPolicies', scanExecutionPoliciesSet),
        ...mapPolicies('namespacePipelineExecutionPolicies', pipelineExecutionPoliciesSet),
        ...mapPolicies(
          'namespaceVulnerabilityManagementPolicies',
          vulnerabilityManagementPoliciesSet,
        ),
      ].sort((a, b) => (a.name > b.name ? 1 : -1));
    },

    policyType() {
      // eslint-disable-next-line no-underscore-dangle
      return this.selectedPolicy ? getPolicyType(this.selectedPolicy.__typename) : '';
    },
    isLoading() {
      return (
        this.$apollo.queries.complianceFrameworkPolicies.loading ||
        this.$apollo.queries.namespacePolicies.loading
      );
    },
  },

  methods: {
    updatePolicies(
      namespaceData,
      {
        approvalField,
        scanExecutionField,
        pipelineExecutionField,
        vulnerabilityManagementField,
        target,
      },
      loadedIndicator,
    ) {
      const {
        policies: pendingApprovalPolicies,
        hasNextPage: hasNextApprovalPolicies,
        endCursor: approvalPoliciesAfter,
      } = extractPolicies(namespaceData[approvalField]);

      const {
        policies: pendingScanExecutionPolicies,
        hasNextPage: hasNextScanExecutionPolicies,
        endCursor: scanExecutionPoliciesAfter,
      } = extractPolicies(namespaceData[scanExecutionField]);

      const {
        policies: pendingPipelineExecutionPolicies,
        hasNextPage: hasNextPipelineExecutionPolicies,
        endCursor: pipelineExecutionPoliciesAfter,
      } = extractPolicies(namespaceData[pipelineExecutionField]);

      const {
        policies: pendingVulnerabilityManagementPolicies,
        hasNextPage: hasNextVulnerabilityManagementPolicies,
        endCursor: vulnerabilityManagementPoliciesAfter,
      } = extractPolicies(namespaceData[vulnerabilityManagementField]);

      this.rawPolicies[`${target}ApprovalPolicies`].push(...pendingApprovalPolicies);
      this.rawPolicies[`${target}ScanExecutionPolicies`].push(...pendingScanExecutionPolicies);
      this.rawPolicies[`${target}PipelineExecutionPolicies`].push(
        ...pendingPipelineExecutionPolicies,
      );
      this.rawPolicies[`${target}VulnerabilityManagementPolicies`].push(
        ...pendingVulnerabilityManagementPolicies,
      );

      this.policiesLoadCursor[`${target}ApprovalPoliciesAfter`] = approvalPoliciesAfter;
      this.policiesLoadCursor[`${target}ScanExecutionPoliciesAfter`] = scanExecutionPoliciesAfter;
      this.policiesLoadCursor[`${target}PipelineExecutionPoliciesAfter`] =
        pipelineExecutionPoliciesAfter;
      this.policiesLoadCursor[`${target}VulnerabilityManagementPoliciesAfter`] =
        vulnerabilityManagementPoliciesAfter;
      this[loadedIndicator] =
        !hasNextApprovalPolicies &&
        !hasNextScanExecutionPolicies &&
        !hasNextPipelineExecutionPolicies &&
        !hasNextVulnerabilityManagementPolicies;
    },

    handleError(error) {
      this.errorMessage = this.$options.i18n.fetchError;
      Sentry.captureException(error);
    },

    openPolicyDrawerFromRow(rows) {
      if (rows.length === 0) return;
      this.openPolicyDrawer(rows[0]);
    },

    openPolicyDrawer(policy) {
      this.selectedPolicy = policy;
    },

    deselectPolicy() {
      this.selectedPolicy = null;
      this.$refs.policiesTable.$children[0].clearSelected();
    },

    onSectionExpand(expanded) {
      this.isExpanded = expanded;
      if (expanded) {
        this.$apollo.queries.namespacePolicies.refetch();
        this.$apollo.queries.complianceFrameworkPolicies.refetch();
      }
    },
  },

  tableFields: [
    {
      key: 'name',
      label: i18n.policiesTableFields.name,
      thClass: '!gl-border-t-0',
      tdClass: '!gl-bg-default md:gl-w-2/5 !gl-border-b-white',
    },
    {
      key: 'description',
      label: i18n.policiesTableFields.desc,
      thClass: '!gl-border-t-0',
      tdClass: '!gl-bg-default md:gl-w-2/5 !gl-border-b-white',
    },
    {
      key: 'action',
      label: i18n.policiesTableFields.action,
      thAlignRight: true,
      thClass: '!gl-border-t-0',
      tdClass: 'gl-text-right md:gl-w-1/5 !gl-bg-default !gl-border-b-white',
    },
  ],
  i18n,
};
</script>

<template>
  <edit-section
    :title="$options.i18n.policies"
    :description="$options.i18n.policiesDescription"
    :items-count="count"
    @toggle="onSectionExpand"
  >
    <gl-table
      v-if="count"
      ref="policiesTable"
      :items="policies"
      :fields="$options.tableFields"
      :busy="isLoading"
      responsive
      stacked="md"
      hover
      selectable
      select-mode="single"
      selected-variant="primary"
      class="gl-mb-6"
      @row-selected="openPolicyDrawerFromRow"
    >
      <template #cell(name)="{ item }">
        <span>{{ item.name }}</span>
        <gl-badge v-if="!item.enabled" variant="muted" class="gl-ml-2">
          {{ __('Disabled') }}
        </gl-badge>
      </template>
      <template #cell(action)="{ item }">
        <gl-button variant="link" @click="openPolicyDrawer(item)">
          {{ __('View details') }}
        </gl-button>
      </template>

      <template #table-busy>
        <gl-skeleton-loader :lines="count" equal-width-lines class="gl-mb-6" />
      </template>
    </gl-table>
    <drawer-wrapper
      container-class=".content-wrapper"
      :open="Boolean(selectedPolicy)"
      :policy="selectedPolicy"
      :policy-type="policyType"
      :disable-scan-policy-update="disableScanPolicyUpdate"
      @close="deselectPolicy"
    />
    <div class="gl-ml-5" data-testid="info-text">
      <gl-icon name="information-o" variant="subtle" class="gl-mr-2" />
      <gl-sprintf :message="$options.i18n.policiesInfoText">
        <template #link="{ content }">
          <gl-link :href="groupSecurityPoliciesPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </div>
  </edit-section>
</template>
