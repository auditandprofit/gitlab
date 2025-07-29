<script>
import { GlSkeletonLoader, GlTooltipDirective } from '@gitlab/ui';
import { GlSparklineChart } from '@gitlab/ui/dist/charts';
import { CHART_GRADIENT, CHART_GRADIENT_INVERTED } from '../../../../dashboards/constants';

export default {
  name: 'TrendLine',
  components: {
    GlSkeletonLoader,
    GlSparklineChart,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    data: {
      type: Array,
      required: true,
    },
    tooltipLabel: {
      type: String,
      required: false,
      default: '',
    },
    invertTrendColor: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    chartGradient() {
      return this.invertTrendColor ? CHART_GRADIENT_INVERTED : CHART_GRADIENT;
    },
  },
};
</script>
<template>
  <div>
    <gl-sparkline-chart
      v-if="data.length"
      :height="30"
      :tooltip-label="tooltipLabel"
      :show-last-y-value="false"
      :data="data"
      :smooth="0.2"
      :gradient="chartGradient"
      connect-nulls
      data-testid="metric-chart"
    />
    <div v-else class="gl-py-4" data-testid="metric-chart-skeleton">
      <gl-skeleton-loader :lines="1" :width="100" />
    </div>
  </div>
</template>
