<script>
import { GlDashboardLayout } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getSystemColorScheme } from '~/lib/utils/css_utils';

import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';

import { isTopLevelGroup } from '../../utils';
import FrameworkCoverage from './framework_coverage.vue';
import FailedRequirements from './failed_requirements.vue';
import FailedControls from './failed_controls.vue';
import FrameworksNeedsAttention from './frameworks_needs_attention.vue';

import frameworkCoverageQuery from './graphql/framework_coverage.query.graphql';
import failedRequirementsQuery from './graphql/failed_requirements.query.graphql';
import failedControlsQuery from './graphql/failed_controls.query.graphql';
import frameworksNeedsAttentionQuery from './graphql/frameworks_needs_attention.query.graphql';

const COVERAGE_MINIMAL_HEIGHT = 2;
const COVERAGE_FRAMEWORKS_PER_UNIT = 7;

const ATTENTION_MINIMAL_HEIGHT = 2.5;
const ATTENTION_FRAMEWORKS_PER_UNIT = 7;

export default {
  components: {
    GlDashboardLayout,
    ExtendedDashboardPanel,
    FrameworkCoverage,
    FrameworksNeedsAttention,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    rootAncestorPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      summary: {
        totalProjects: 0,
        coveredCount: 0,
        details: [],
      },
      failedRequirements: {
        failed: 0,
        passed: 0,
        pending: 0,
      },
      failedControls: {
        failed: 0,
        passed: 0,
        pending: 0,
      },
      frameworksNeedsAttention: [],
      colorScheme: getSystemColorScheme(),
    };
  },
  apollo: {
    summary: {
      query: frameworkCoverageQuery,
      variables() {
        return {
          groupPath: this.groupPath,
        };
      },
      update(data) {
        const { totalProjects, coveredCount } = data.group.complianceFrameworkCoverageSummary;
        const { nodes: details } = data.group.complianceFrameworksCoverageDetails;
        return {
          totalProjects,
          coveredCount,
          details,
        };
      },
      error(error) {
        this.handleGenericError(error);
      },
    },
    failedRequirements: {
      query: failedRequirementsQuery,
      variables() {
        return {
          groupPath: this.groupPath,
        };
      },
      update(data) {
        return data.group.complianceRequirementCoverage;
      },
      error(error) {
        this.handleGenericError(error);
      },
    },
    failedControls: {
      query: failedControlsQuery,
      variables() {
        return {
          groupPath: this.groupPath,
        };
      },
      update(data) {
        return data.group.complianceRequirementControlCoverage;
      },
      error(error) {
        this.handleGenericError(error);
      },
    },
    frameworksNeedsAttention: {
      query: frameworksNeedsAttentionQuery,
      variables() {
        return {
          groupPath: this.groupPath,
        };
      },
      update(data) {
        return data.group.complianceFrameworksNeedingAttention.nodes;
      },
      error(error) {
        this.handleGenericError(error);
      },
    },
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestorPath);
    },
    dashboardConfig() {
      const coverageHeight =
        COVERAGE_MINIMAL_HEIGHT +
        Math.ceil(this.summary.details.length / COVERAGE_FRAMEWORKS_PER_UNIT);

      const needsAttentionHeight =
        ATTENTION_MINIMAL_HEIGHT +
        Math.ceil(this.frameworksNeedsAttention.length / ATTENTION_FRAMEWORKS_PER_UNIT);

      return {
        panels: [
          {
            id: '1',
            extendedDashboardPanelProps: {
              title: s__('ComplianceReport|Compliance framework coverage'),
              loading: this.$apollo.queries.summary.loading,
            },
            component: FrameworkCoverage,
            componentProps: {
              summary: this.summary,
              isTopLevelGroup: this.isTopLevelGroup,
              colorScheme: this.colorScheme,
            },
            gridAttributes: {
              width: 12,
              height: coverageHeight,
              yPos: 0,
              xPos: 0,
            },
          },
          {
            id: '2',
            extendedDashboardPanelProps: {
              title: s__('ComplianceReport|Requirements'),
              loading: this.$apollo.queries.failedRequirements.loading,
            },
            component: FailedRequirements,
            componentProps: {
              failedRequirements: this.failedRequirements,
              colorScheme: this.colorScheme,
            },
            gridAttributes: {
              width: 6,
              height: 3,
              yPos: coverageHeight,
              xPos: 0,
            },
          },
          {
            id: '3',
            extendedDashboardPanelProps: {
              title: s__('ComplianceReport|Controls'),
              loading: this.$apollo.queries.failedControls.loading,
            },
            component: FailedControls,
            componentProps: {
              failedControls: this.failedControls,
              colorScheme: this.colorScheme,
            },
            gridAttributes: {
              width: 6,
              height: 3,
              yPos: coverageHeight,
              xPos: 6,
            },
          },
          this.frameworksNeedsAttention.length
            ? {
                id: '4',
                extendedDashboardPanelProps: {
                  title: s__('ComplianceReport|Frameworks needs attention'),
                  loading: this.$apollo.queries.frameworksNeedsAttention.loading,
                },
                component: FrameworksNeedsAttention,
                componentProps: {
                  frameworks: this.frameworksNeedsAttention,
                },
                gridAttributes: {
                  width: 12,
                  height: needsAttentionHeight,
                  yPos: coverageHeight + 3,
                  xPos: 0,
                },
              }
            : null,
        ].filter(Boolean),
      };
    },
  },
  methods: {
    handleGenericError(error) {
      createAlert({
        message: __('Something went wrong on our end.'),
      });
      Sentry.captureException(error);
    },
  },
};
</script>

<template>
  <gl-dashboard-layout :config="dashboardConfig">
    <template #panel="{ panel }">
      <extended-dashboard-panel v-bind="panel.extendedDashboardPanelProps">
        <template #body>
          <component
            :is="panel.component"
            class="gl-h-full gl-overflow-hidden"
            v-bind="panel.componentProps"
          />
        </template>
      </extended-dashboard-panel>
    </template>
  </gl-dashboard-layout>
</template>
