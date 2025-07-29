<script>
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  dateAtFirstDayOfMonth,
  nMonthsBefore,
} from '~/lib/utils/datetime/date_calculation_utility';

import getGroupCurrentAndPrevProductAnalyticsUsageQuery from '../../graphql/queries/get_group_product_analytics_usage.query.graphql';
import { projectHasProductAnalyticsEnabled } from '../../utils';
import ProductAnalyticsProjectsUsageChart from './product_analytics_projects_usage_chart.vue';
import ProductAnalyticsProjectsUsageTable from './product_analytics_projects_usage_table.vue';

export default {
  name: 'ProductAnalyticsProjectsUsage',
  components: {
    GlAlert,
    ProductAnalyticsProjectsUsageChart,
    ProductAnalyticsProjectsUsageTable,
  },
  inject: {
    namespacePath: {
      type: String,
    },
  },
  data() {
    return {
      error: null,
      projectsUsageData: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.projectsUsageData.loading;
    },
  },
  apollo: {
    projectsUsageData: {
      query: getGroupCurrentAndPrevProductAnalyticsUsageQuery,
      variables() {
        const current = dateAtFirstDayOfMonth(new Date());
        const previous = nMonthsBefore(current, 1);

        return {
          namespacePath: this.namespacePath,
          monthSelection: [
            // note: JS `getMonth()` is 0 based, so add 1
            { year: current.getFullYear(), month: current.getMonth() + 1 },
            { year: previous.getFullYear(), month: previous.getMonth() + 1 },
          ],
        };
      },
      update(data) {
        return data.group.projects.nodes.filter(projectHasProductAnalyticsEnabled);
      },
      error(error) {
        this.error = error;
        Sentry.captureException(error);
      },
    },
  },
};
</script>
<template>
  <section>
    <h2 class="gl-text-lg">{{ s__('ProductAnalytics|Usage by project') }}</h2>
    <gl-alert v-if="error" variant="danger" :dismissible="false">
      {{
        s__(
          'ProductAnalytics|Something went wrong while loading product analytics usage data. Refresh the page to try again.',
        )
      }}
    </gl-alert>
    <template v-else>
      <product-analytics-projects-usage-chart
        :is-loading="isLoading"
        :projects-usage-data="projectsUsageData"
      />
      <product-analytics-projects-usage-table
        :is-loading="isLoading"
        :projects-usage-data="projectsUsageData"
      />
    </template>
  </section>
</template>
