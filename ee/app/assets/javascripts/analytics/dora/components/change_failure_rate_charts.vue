<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  DORA_METRICS_QUERY_TYPE,
  CHANGE_FAILURE_RATE_SECONDARY_SERIES_NAME,
} from '~/analytics/shared/constants';
import ValueStreamMetrics from '~/analytics/shared/components/value_stream_metrics.vue';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import CiCdAnalyticsCharts from '~/analytics/ci_cd/components/ci_cd_analytics_charts.vue';
import { CHANGE_FAILURE_RATE, getProjectDoraMetrics, getGroupDoraMetrics } from '../api/dora_api';
import { buildNullSeries } from '../../shared/utils';
import ChartTooltipText from '../../shared/components/chart_tooltip_text.vue';
import DoraChartHeader from './dora_chart_header.vue';
import {
  allChartDefinitions,
  areaChartOptions,
  averageSeriesOptions,
  chartDescriptionText,
  chartDocumentationHref,
  LAST_WEEK,
  LAST_MONTH,
  LAST_90_DAYS,
  LAST_180_DAYS,
  CHART_TITLE,
} from './static_data/change_failure_rate';
import {
  apiDataToChartSeries,
  seriesToMedianSeries,
  extractTimeSeriesTooltip,
  formatAsPercentage,
  extractOverviewMetricsQueryParameters,
} from './util';

const VISIBLE_METRICS = [CHANGE_FAILURE_RATE];

// The metrics API endpoint returns a few different types of metrics, we only want change failure rate here
const extractFailureRateMetrics = (data) =>
  data.filter((d) => VISIBLE_METRICS.includes(d.identifier)).map(({ links, ...rest }) => rest);

export default {
  name: 'ChangeFailureRateCharts',
  components: {
    CiCdAnalyticsCharts,
    DoraChartHeader,
    ChartTooltipText,
    ValueStreamMetrics,
  },
  inject: {
    projectPath: {
      type: String,
      default: '',
    },
    groupPath: {
      type: String,
      default: '',
    },
    shouldRenderDoraCharts: {
      type: Boolean,
      default: false,
    },
  },
  chartInDays: {
    [LAST_WEEK]: 7,
    [LAST_MONTH]: 30,
    [LAST_90_DAYS]: 90,
    [LAST_180_DAYS]: 180,
  },
  data() {
    return {
      chartData: {
        [LAST_WEEK]: [],
        [LAST_MONTH]: [],
        [LAST_90_DAYS]: [],
        [LAST_180_DAYS]: [],
      },
      tooltipTitle: null,
      tooltipValue: null,
    };
  },
  computed: {
    charts() {
      return allChartDefinitions.map((chart) => ({
        ...chart,
        data: this.chartData[chart.id],
      }));
    },
    metricsRequestPath() {
      return this.projectPath || this.groupPath;
    },
  },
  async mounted() {
    try {
      await this.getChartData();
    } catch (error) {
      createAlert({
        message: s__('DORA4Metrics|Something went wrong while getting change failure rate data.'),
      });

      Sentry.captureException(
        new Error(`Something went wrong while getting change failure rate data:\n${error.message}`),
      );
    }
  },
  methods: {
    async getChartData() {
      if (this.projectPath && this.groupPath) {
        throw new Error('Both projectPath and groupPath were provided');
      }

      const requestPath = this.projectPath || this.groupPath;

      if (!requestPath) {
        throw new Error('Either projectPath or groupPath must be provided');
      }

      const getDoraMetrics = this.projectPath ? getProjectDoraMetrics : getGroupDoraMetrics;

      const results = await Promise.allSettled(
        allChartDefinitions.map(async ({ id, requestParams, startDate, endDate }) => {
          const { data: apiData } = await getDoraMetrics(
            requestPath,
            CHANGE_FAILURE_RATE,
            requestParams,
          );

          const seriesData = apiDataToChartSeries(apiData, startDate, endDate, CHART_TITLE, null);

          // The nullSeries is used to indicate sections of the chart that have no data available
          // This is displayed as the third series and is different to sections that have values of `0`
          const nullSeries = buildNullSeries({
            seriesData,
            nullSeriesTitle: this.$options.i18n.noIncidents,
          });

          const { data } = seriesData[0];

          const medianSeries = {
            ...averageSeriesOptions,
            ...seriesToMedianSeries(
              data,
              sprintf(CHANGE_FAILURE_RATE_SECONDARY_SERIES_NAME, {
                days: this.$options.chartInDays[id],
              }),
            ),
          };

          this.chartData[id] = [nullSeries[1], medianSeries, nullSeries[0]];
        }),
      );

      const requestErrors = results.filter((r) => r.status === 'rejected').map((r) => r.reason);

      if (requestErrors.length) {
        const allErrorMessages = requestErrors.join('\n');
        throw new Error(allErrorMessages);
      }
    },
    getMetricsRequestParams(selectedChart) {
      return extractOverviewMetricsQueryParameters(allChartDefinitions[selectedChart]);
    },
    formatTooltipText(params) {
      const { tooltipTitle, tooltipValue } = extractTimeSeriesTooltip(
        params,
        CHART_TITLE,
        formatAsPercentage,
      );
      this.tooltipTitle = tooltipTitle;
      this.tooltipValue = tooltipValue;
    },
  },
  areaChartOptions,
  chartDescriptionText,
  chartDocumentationHref,
  extractFailureRateMetrics,
  i18n: {
    noIncidents: s__('DORA4Metrics|No incidents during this period'),
  },
  DORA_METRICS_QUERY_TYPE,
};
</script>
<template>
  <div data-testid="change-failure-rate-charts">
    <dora-chart-header
      :header-text="s__('DORA4Metrics|Change failure rate')"
      :chart-description-text="$options.chartDescriptionText"
      :chart-documentation-href="$options.chartDocumentationHref"
    />
    <ci-cd-analytics-charts
      :charts="charts"
      :chart-options="$options.areaChartOptions"
      :format-tooltip-text="formatTooltipText"
    >
      <template #metrics="{ selectedChart }">
        <value-stream-metrics
          :request-path="metricsRequestPath"
          :request-params="getMetricsRequestParams(selectedChart)"
          :filter-fn="$options.extractFailureRateMetrics"
          :query-type="$options.DORA_METRICS_QUERY_TYPE"
          :is-licensed="shouldRenderDoraCharts"
        />
      </template>
      <template #tooltip-title> {{ tooltipTitle }} </template>
      <template #tooltip-content>
        <chart-tooltip-text
          :empty-value-text="$options.i18n.noIncidents"
          :tooltip-value="tooltipValue"
        />
      </template>
    </ci-cd-analytics-charts>
  </div>
</template>
