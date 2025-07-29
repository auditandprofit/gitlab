<script>
import { GlDiscreteScatterChart, GlChartLegend } from '@gitlab/ui/dist/charts';
import { isNil } from 'lodash';
import { GlAlert } from '@gitlab/ui';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { DURATION_STAGE_TIME_LABEL } from 'ee/analytics/cycle_analytics/constants';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { sprintf, __, s__ } from '~/locale';
import {
  TYPENAME_ISSUE,
  TYPENAME_MERGE_REQUEST,
  TYPENAME_WORK_ITEM,
} from '~/graphql_shared/constants';
import {
  getDatesInRange,
  millisecondsToSeconds,
} from '~/lib/utils/datetime/date_calculation_utility';
import { humanizeTimeInterval } from '~/lib/utils/datetime/date_format_utility';
import { formatDurationChartDate } from 'ee/analytics/cycle_analytics/utils';
import NoDataAvailableState from '../no_data_available_state.vue';

const formatChartValue = (value) =>
  humanizeTimeInterval(millisecondsToSeconds(value), { abbreviated: true });

export default {
  name: 'StageScatterChart',
  components: {
    NoDataAvailableState,
    GlDiscreteScatterChart,
    GlChartLegend,
    GlAlert,
    ChartSkeletonLoader,
  },
  props: {
    stageTitle: {
      type: String,
      required: true,
    },
    issuableType: {
      type: String,
      required: false,
      default: TYPENAME_WORK_ITEM,
      validator: (value) =>
        [TYPENAME_ISSUE, TYPENAME_MERGE_REQUEST, TYPENAME_WORK_ITEM].includes(value),
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    plottableData: {
      type: Array,
      required: false,
      default: () => [],
    },
    errorMessage: {
      type: String,
      required: false,
      default: '',
    },
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
  },
  data() {
    return {
      chart: null,
      tooltip: {
        title: null,
        content: {
          label: null,
          value: null,
        },
      },
    };
  },
  computed: {
    hasPlottableData() {
      return this.plottableData.some(([, value]) => !isNil(value));
    },
    chartTitle() {
      return sprintf(DURATION_STAGE_TIME_LABEL, {
        title: capitalizeFirstCharacter(this.stageTitle),
      });
    },
    timeInStageSeriesName() {
      const issuableLabels = {
        [TYPENAME_WORK_ITEM]: __('Work item'),
        [TYPENAME_ISSUE]: __('Issue'),
        [TYPENAME_MERGE_REQUEST]: __('Merge request'),
      };

      return sprintf(s__('CycleAnalytics|%{issuableType} time in stage'), {
        issuableType: issuableLabels[this.issuableType],
      });
    },
    chartData() {
      return [
        {
          type: 'scatter',
          name: this.timeInStageSeriesName,
          data: this.plottableData.map(([date, value]) => [formatDurationChartDate(date), value]),
        },
      ];
    },
    compiledChartOptions() {
      return this.chart ? this.chart.getOption() : null;
    },
    legendSeriesInfo() {
      if (!this.compiledChartOptions) return [];

      const { series } = this.compiledChartOptions;

      return series.map(({ type, name, lineStyle: { color } }) => ({ type, name, color }));
    },
    chartOptions() {
      return {
        yAxis: {
          type: 'value',
          axisLabel: {
            formatter: (value) => formatChartValue(value),
          },
        },
        xAxis: {
          type: 'category',
          data: getDatesInRange(this.startDate, this.endDate, formatDurationChartDate),
        },
      };
    },
  },
  methods: {
    onChartCreated(chart) {
      this.chart = chart;
      this.chart.setOption({ lazyUpdate: true });
    },
    formatTooltipText({ data }) {
      const [date, value] = data;

      this.tooltip = {
        title: date,
        content: {
          label: this.$options.i18n.yAxisTitle,
          value: formatChartValue(value),
        },
      };
    },
  },
  i18n: {
    yAxisTitle: __('Duration'),
    xAxisTitle: __('Date'),
  },
};
</script>

<template>
  <chart-skeleton-loader v-if="isLoading && !hasPlottableData" />
  <div v-else data-testid="vsa-duration-chart">
    <h2 class="gl-heading-3">{{ chartTitle }}</h2>
    <gl-alert v-if="errorMessage" variant="danger" :dismissible="false">{{
      errorMessage
    }}</gl-alert>
    <div v-else-if="hasPlottableData">
      <gl-discrete-scatter-chart
        :data="chartData"
        :x-axis-title="$options.i18n.xAxisTitle"
        :y-axis-title="$options.i18n.yAxisTitle"
        :option="chartOptions"
        :format-tooltip-text="formatTooltipText"
        @created="onChartCreated"
      >
        <template #tooltip-title>{{ tooltip.title }}</template>
        <template #tooltip-content>
          <div class="gl-flex gl-justify-between">
            <div class="gl-mr-5">{{ tooltip.content.label }}</div>
            <div class="gl-font-bold">{{ tooltip.content.value }}</div>
          </div>
        </template>
      </gl-discrete-scatter-chart>
      <gl-chart-legend v-if="chart" :chart="chart" :series-info="legendSeriesInfo" />
    </div>
    <no-data-available-state v-else />
  </div>
</template>
