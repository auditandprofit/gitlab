<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/dist/charts';

import { s__ } from '~/locale';

import { monthlyTotalsValidator } from '../utils';

export default {
  name: 'ProductAnalyticsGroupMonthlyUsageChart',
  components: {
    GlAreaChart,
    GlSkeletonLoader,
  },
  props: {
    isLoading: {
      type: Boolean,
      required: true,
    },
    monthlyTotals: {
      type: Array,
      required: false,
      default: null,
      validator: monthlyTotalsValidator,
    },
  },
  computed: {
    chartData() {
      return [
        {
          name: s__('ProductAnalytics|Analytics events by month'),
          data: this.monthlyTotals,
        },
      ];
    },
  },
  CHART_OPTIONS: {
    yAxis: {
      name: s__('ProductAnalytics|Events'),
    },
    xAxis: {
      name: s__('ProductAnalytics|Month'),
      type: 'category',
    },
  },
};
</script>
<template>
  <section>
    <h2 class="gl-text-lg">{{ s__('ProductAnalytics|Usage by month') }}</h2>

    <gl-skeleton-loader v-if="isLoading" :lines="3" />
    <template v-else>
      <gl-area-chart :data="chartData" :option="$options.CHART_OPTIONS" />
    </template>
  </section>
</template>
