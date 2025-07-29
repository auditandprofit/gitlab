<script>
import { GlTooltipDirective } from '@gitlab/ui';
import { UNITS } from '~/analytics/shared/constants';
import TrendIndicator from '../../../../dashboards/components/trend_indicator.vue';
import { formatMetric } from '../../../../dashboards/utils';

export default {
  name: 'ChangePercentageIndicator',
  components: {
    TrendIndicator,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    value: {
      type: [String, Number],
      required: true,
    },
    tooltip: {
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
    formatInvalidTrend() {
      return this.value === 0 ? formatMetric(0, UNITS.PERCENT) : this.value;
    },
    isValidTrend() {
      return typeof this.value === 'number' && this.value !== 0;
    },
  },
};
</script>
<template>
  <div>
    <trend-indicator v-if="isValidTrend" :change="value" :invert-color="invertTrendColor" />
    <span
      v-else
      v-gl-tooltip="tooltip"
      :aria-label="tooltip"
      class="gl-cursor-pointer gl-text-sm gl-text-subtle hover:gl-underline"
      data-testid="metric-cell-no-change"
      tabindex="0"
    >
      {{ formatInvalidTrend }}
    </span>
  </div>
</template>
