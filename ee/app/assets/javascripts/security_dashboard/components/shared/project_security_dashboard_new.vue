<script>
import { GlDashboardLayout } from '@gitlab/ui';
import { s__ } from '~/locale';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import { REPORT_TYPE_VENDOR_TOKEN_DEFINITION } from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/constants';
import ProjectVulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/project_vulnerabilities_over_time_panel.vue';

export default {
  components: {
    GlDashboardLayout,
    FilteredSearch,
  },
  data() {
    return {
      filters: {},
    };
  },
  computed: {
    dashboard() {
      return {
        title: s__('SecurityReports|Security dashboard'),
        description: s__(
          // Note: This is just a placeholder text and will be replaced with the final copy, once it is ready
          'SecurityReports|This dashboard provides an overview of your security vulnerabilities.',
        ),
        panels: [
          {
            id: '1',
            component: markRaw(ProjectVulnerabilitiesOverTimePanel),
            componentProps: {
              filters: this.filters,
            },
            gridAttributes: {
              width: 6,
              height: 4,
              yPos: 0,
              xPos: 0,
            },
          },
        ],
      };
    },
  },
  methods: {
    updateFilters(newFilters) {
      this.filters = newFilters;
    },
  },
  filteredSearchTokens: [REPORT_TYPE_VENDOR_TOKEN_DEFINITION],
};
</script>

<template>
  <gl-dashboard-layout :config="dashboard" data-testid="project-security-dashboard-new">
    <template #filters>
      <filtered-search :tokens="$options.filteredSearchTokens" @filters-changed="updateFilters" />
    </template>
    <template #panel="{ panel }">
      <component :is="panel.component" v-bind="panel.componentProps" />
    </template>
  </gl-dashboard-layout>
</template>
