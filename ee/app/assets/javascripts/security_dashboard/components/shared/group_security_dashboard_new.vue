<script>
import { GlDashboardLayout } from '@gitlab/ui';
import { s__ } from '~/locale';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/project_token.vue';
import GroupVulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/group_vulnerabilities_over_time_panel.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';

const PROJECT_TOKEN_DEFINITION = {
  type: 'projectId',
  title: ProjectToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: markRaw(ProjectToken),
  operators: OPERATORS_OR,
};

export default {
  components: {
    GlDashboardLayout,
    FilteredSearch,
  },
  inject: ['groupFullPath'],
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
            component: markRaw(GroupVulnerabilitiesOverTimePanel),
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
      if (Object.keys(newFilters).length === 0) {
        this.filters = {};
      } else {
        this.filters = { ...this.filters, ...newFilters };
      }
    },
  },
  filteredSearchTokens: [PROJECT_TOKEN_DEFINITION],
};
</script>

<template>
  <gl-dashboard-layout :config="dashboard" data-testid="group-security-dashboard-new">
    <template #filters>
      <filtered-search :tokens="$options.filteredSearchTokens" @filters-changed="updateFilters" />
    </template>
    <template #panel="{ panel }">
      <component :is="panel.component" v-bind="panel.componentProps" />
    </template>
  </gl-dashboard-layout>
</template>
