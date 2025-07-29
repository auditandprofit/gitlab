<script>
import { GlToggle, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import { GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { BASE_FORECAST_SERIES_OPTIONS } from 'ee/analytics/shared/constants';
import { linearRegression } from 'ee/analytics/shared/utils';
import SafeHtml from '~/vue_shared/directives/safe_html';
import ValueStreamMetrics from '~/analytics/shared/components/value_stream_metrics.vue';
import {
  ALL_METRICS_QUERY_TYPE,
  DEPLOYMENT_FREQUENCY_SECONDARY_SERIES_NAME,
} from '~/analytics/shared/constants';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import { spriteIcon } from '~/lib/utils/common_utils';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import CiCdAnalyticsCharts from '~/analytics/ci_cd/components/ci_cd_analytics_charts.vue';
import { DEFAULT_SELECTED_CHART } from '~/analytics/ci_cd/components/constants';
import { PROMO_URL } from '~/constants';
import {
  DEPLOYMENT_FREQUENCY_METRIC_TYPE,
  getProjectDoraMetrics,
  getGroupDoraMetrics,
} from '../api/dora_api';
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
} from './static_data/deployment_frequency';
import {
  apiDataToChartSeries,
  seriesToAverageSeries,
  forecastDataToSeries,
  extractOverviewMetricsQueryParameters,
} from './util';

const VISIBLE_METRICS = ['deploys', 'deployment-frequency', 'deployment_frequency'];
const filterFn = (data) =>
  data.filter((d) => VISIBLE_METRICS.includes(d.identifier)).map(({ links, ...rest }) => rest);

const TESTING_TERMS_URL = `${PROMO_URL}/handbook/legal/testing-agreement/`;
const FORECAST_FEEDBACK_ISSUE_URL = 'https://gitlab.com/gitlab-org/gitlab/-/issues/416833';

export default {
  name: 'DeploymentFrequencyCharts',
  components: {
    CiCdAnalyticsCharts,
    DoraChartHeader,
    ValueStreamMetrics,
    GlToggle,
    GlAlert,
    GlSprintf,
    GlLink,
    GlChartSeriesLabel,
  },
  directives: {
    SafeHtml,
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
  forecastDays: {
    [LAST_WEEK]: 3,
    [LAST_MONTH]: 14,
    [LAST_90_DAYS]: 45,
    [LAST_180_DAYS]: 90,
  },
  i18n: {
    showForecast: s__('DORA4Metrics|Show forecast'),
    forecast: s__('DORA4Metrics|Forecast'),
    confirmationTitle: s__('DORA4Metrics|Accept testing terms of use?'),
    confirmationBtnText: s__('DORA4Metrics|Accept testing terms'),
    confirmationHtmlMessage: sprintf(
      s__('DORA4Metrics|By enabling this feature, you accept the %{url}'),
      {
        url: `<a href="${TESTING_TERMS_URL}" target="_blank" rel="noopener noreferrer nofollow">Testing Terms of Use ${spriteIcon(
          'external-link',
          's16',
        )}</a>`,
      },
      false,
    ),
    forecastFeedbackText: sprintf(
      s__(
        'DORA4Metrics|To help us improve the Show forecast feature, please share feedback about your experience in %{linkStart}this issue%{linkEnd}.',
      ),
    ),
  },
  data() {
    return {
      chartData: {
        [LAST_WEEK]: [],
        [LAST_MONTH]: [],
        [LAST_90_DAYS]: [],
        [LAST_180_DAYS]: [],
      },
      showForecast: false,
      forecastConfirmed: false,
      forecastChartData: {
        [LAST_WEEK]: [],
        [LAST_MONTH]: [],
        [LAST_90_DAYS]: [],
        [LAST_180_DAYS]: [],
      },
      rawApiData: {
        [LAST_WEEK]: [],
        [LAST_MONTH]: [],
        [LAST_90_DAYS]: [],
        [LAST_180_DAYS]: [],
      },
      selectedChartIndex: DEFAULT_SELECTED_CHART,
      tooltipTitle: '',
      tooltipContent: [],
    };
  },
  computed: {
    charts() {
      return allChartDefinitions.map((chart) => {
        const data = [...this.chartData[chart.id]];
        if (this.showForecast) {
          data.push(this.forecastChartData[chart.id]);
        }
        return { ...chart, data };
      });
    },
    metricsRequestPath() {
      return this.projectPath ? this.projectPath : this.groupPath;
    },
    selectedChartDefinition() {
      return allChartDefinitions[this.selectedChartIndex];
    },
    selectedChartId() {
      return this.selectedChartDefinition.id;
    },
    selectedForecast() {
      return this.forecastChartData[this.selectedChartId];
    },
    selectedDataSeries() {
      return this.chartData[this.selectedChartId][0];
    },
    shouldBuildForecast() {
      return this.showForecast && this.forecastConfirmed && !this.selectedForecast?.data.length;
    },
    forecastHorizon() {
      return this.$options.forecastDays[this.selectedChartId];
    },
  },
  async mounted() {
    const results = await Promise.allSettled(
      allChartDefinitions.map(async ({ id, requestParams, startDate, endDate }) => {
        let apiData;
        if (this.projectPath && this.groupPath) {
          throw new Error('Both projectPath and groupPath were provided');
        } else if (this.projectPath) {
          apiData = (
            await getProjectDoraMetrics(
              this.projectPath,
              DEPLOYMENT_FREQUENCY_METRIC_TYPE,
              requestParams,
            )
          ).data;
        } else if (this.groupPath) {
          apiData = (
            await getGroupDoraMetrics(
              this.groupPath,
              DEPLOYMENT_FREQUENCY_METRIC_TYPE,
              requestParams,
            )
          ).data;
        } else {
          throw new Error('Either projectPath or groupPath must be provided');
        }

        const seriesData = apiDataToChartSeries(apiData, startDate, endDate, CHART_TITLE);
        const { data } = seriesData[0];

        this.chartData[id] = [
          ...seriesData,
          {
            ...averageSeriesOptions,
            ...seriesToAverageSeries(
              data,
              sprintf(DEPLOYMENT_FREQUENCY_SECONDARY_SERIES_NAME, {
                days: this.$options.chartInDays[id],
              }),
            ),
          },
        ];

        this.rawApiData[id] = apiData;
        this.forecastChartData[id] = {
          ...BASE_FORECAST_SERIES_OPTIONS,
          name: this.$options.i18n.forecast,
          data: [],
        };
      }),
    );

    const requestErrors = results.filter((r) => r.status === 'rejected').map((r) => r.reason);

    if (requestErrors.length) {
      createAlert({
        message: s__('DORA4Metrics|Something went wrong while getting deployment frequency data.'),
      });

      const allErrorMessages = requestErrors.join('\n');
      Sentry.captureException(
        new Error(
          `Something went wrong while getting deployment frequency data:\n${allErrorMessages}`,
        ),
      );
    }
  },
  methods: {
    onSelectChart(selectedChartIndex) {
      this.selectedChartIndex = selectedChartIndex;
      this.calculateForecast();
    },
    getMetricsRequestParams(selectedChart) {
      return extractOverviewMetricsQueryParameters(allChartDefinitions[selectedChart]);
    },
    calculateForecast() {
      if (!this.shouldBuildForecast) return;

      const { endDate } = this.selectedChartDefinition;
      const { selectedChartId: id, forecastHorizon } = this;
      const forecastData = linearRegression(this.rawApiData[id], forecastHorizon);

      this.forecastChartData[id].data = forecastDataToSeries({
        forecastData,
        forecastHorizon,
        endDate,
        dataSeries: this.selectedDataSeries.data,
        forecastSeriesLabel: this.$options.i18n.forecast,
      });
    },
    async onToggleForecast(toggleValue) {
      if (toggleValue) {
        await this.confirmForecastTerms();
        if (this.forecastConfirmed) {
          this.showForecast = toggleValue;
          this.calculateForecast();
        }
      } else {
        this.showForecast = toggleValue;
      }
    },
    async confirmForecastTerms() {
      if (this.forecastConfirmed) return;

      const {
        confirmationTitle: title,
        confirmationBtnText: primaryBtnText,
        confirmationHtmlMessage: modalHtmlMessage,
      } = this.$options.i18n;

      this.forecastConfirmed = await confirmAction('', {
        primaryBtnVariant: 'confirm',
        primaryBtnText,
        title,
        modalHtmlMessage,
      });
    },
    formatTooltipText({ value, seriesData }) {
      this.tooltipTitle = value;
      this.tooltipContent = seriesData.map(({ seriesId, seriesName, color, value: metric }) => ({
        key: seriesId,
        name: seriesName,
        color,
        value: metric[1],
      }));
    },
  },
  areaChartOptions,
  chartDescriptionText,
  chartDocumentationHref,
  filterFn,
  FORECAST_FEEDBACK_ISSUE_URL,
  ALL_METRICS_QUERY_TYPE,
};
</script>
<template>
  <div data-testid="deployment-frequency-charts">
    <dora-chart-header
      :header-text="s__('DORA4Metrics|Deployment frequency')"
      :chart-description-text="$options.chartDescriptionText"
      :chart-documentation-href="$options.chartDocumentationHref"
    />
    <ci-cd-analytics-charts
      :charts="charts"
      :chart-options="$options.areaChartOptions"
      :format-tooltip-text="formatTooltipText"
      @select-chart="onSelectChart"
    >
      <template #tooltip-title>{{ tooltipTitle }}</template>
      <template #tooltip-content>
        <div
          v-for="{ key, name, color, value } in tooltipContent"
          :key="key"
          class="gl-flex gl-justify-between"
        >
          <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">
            {{ name }}
          </gl-chart-series-label>
          <div class="gl-font-bold">{{ value }}</div>
        </div>
      </template>
      <template #extend-button-group>
        <div class="gl-flex gl-items-center">
          <gl-toggle
            :value="showForecast"
            :label="$options.i18n.showForecast"
            label-position="left"
            data-testid="data-forecast-toggle"
            @change="onToggleForecast"
          />
        </div>
      </template>
      <template #alerts>
        <gl-alert
          v-if="showForecast"
          class="gl-my-5"
          data-testid="forecast-feedback"
          variant="info"
          :dismissible="false"
        >
          <gl-sprintf :message="$options.i18n.forecastFeedbackText">
            <template #link="{ content }">
              <gl-link
                class="!gl-no-underline"
                :href="$options.FORECAST_FEEDBACK_ISSUE_URL"
                target="_blank"
                >{{ content }}</gl-link
              >
            </template>
          </gl-sprintf>
        </gl-alert>
      </template>
      <template #metrics="{ selectedChart }">
        <value-stream-metrics
          :request-path="metricsRequestPath"
          :request-params="getMetricsRequestParams(selectedChart)"
          :filter-fn="$options.filterFn"
          :query-type="$options.ALL_METRICS_QUERY_TYPE"
          :is-licensed="shouldRenderDoraCharts"
        />
      </template>
    </ci-cd-analytics-charts>
  </div>
</template>
