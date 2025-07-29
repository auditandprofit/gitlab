<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { formatDate, getDateInPast } from '~/lib/utils/datetime_utility';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import getVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/get_group_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_formatters';

export default {
  name: 'GroupVulnerabilitiesOverTimePanel',
  components: {
    ExtendedDashboardPanel,
    VulnerabilitiesOverTimeChart,
  },
  inject: ['groupFullPath'],
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  defaultStartDate: 90,
  apollo: {
    vulnerabilitiesOverTime: {
      query: getVulnerabilitiesOverTime,
      variables() {
        const { projectId } = this.filters;
        const startDate = formatDate(
          getDateInPast(new Date(), this.$options.defaultStartDate),
          'isoDate',
        );
        const endDate = formatDate(new Date(), 'isoDate');

        return {
          ...(projectId ? { projectId } : {}),
          fullPath: this.groupFullPath,
          startDate,
          endDate,
        };
      },
      update(data) {
        const rawData = data.group?.securityMetrics?.vulnerabilitiesOverTime?.nodes || [];
        return formatVulnerabilitiesOverTimeData(rawData);
      },
      error() {
        this.fetchError = true;
      },
    },
  },
  data() {
    return {
      vulnerabilitiesOverTime: [],
      fetchError: false,
    };
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|Vulnerabilities over time')"
    :loading="$apollo.queries.vulnerabilitiesOverTime.loading"
    :show-alert-state="fetchError"
  >
    <template #body>
      <vulnerabilities-over-time-chart
        v-if="!fetchError"
        class="gl-h-full gl-overflow-hidden gl-p-2"
        :chart-series="vulnerabilitiesOverTime"
      />
      <p v-else>{{ __('Something went wrong. Please try again.') }}</p>
    </template>
  </extended-dashboard-panel>
</template>
