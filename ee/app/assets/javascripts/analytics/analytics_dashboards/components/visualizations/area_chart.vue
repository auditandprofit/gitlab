<script>
import { GlAreaChart } from '@gitlab/ui/dist/charts';
import { merge } from 'lodash';
import { AREA_CHART_SERIES_OPTIONS } from 'ee/analytics/shared/constants';
import { formatVisualizationTooltipTitle, formatVisualizationValue } from './utils';

export default {
  name: 'AreaChart',
  components: {
    GlAreaChart,
  },
  props: {
    data: {
      type: Array,
      required: false,
      default: () => [],
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    fullOptions() {
      return merge(this.$options.defaultChartOptions, this.options);
    },
    chartData() {
      return this.data.map((seriesData) => ({
        ...seriesData,
        ...AREA_CHART_SERIES_OPTIONS,
      }));
    },
  },
  methods: {
    formatVisualizationValue,
    formatVisualizationTooltipTitle,
  },
  defaultChartOptions: {
    xAxis: {
      type: 'category',
    },
    yAxis: {
      type: 'value',
    },
  },
};
</script>

<template>
  <gl-area-chart
    :data="chartData"
    :option="fullOptions"
    height="auto"
    data-testid="dashboard-visualization-area-chart"
  >
    <template #tooltip-title="{ title, params }">
      {{ formatVisualizationTooltipTitle(title, params) }}</template
    >
    <template #tooltip-value="{ value }">{{ formatVisualizationValue(value) }}</template>
  </gl-area-chart>
</template>
