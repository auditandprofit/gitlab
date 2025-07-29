<script>
import { uniq } from 'lodash';
import {
  GlTableLite,
  GlSkeletonLoader,
  GlTooltip,
  GlTooltipDirective,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import { GlSparklineChart } from '@gitlab/ui/dist/charts';
import { toYmd, extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { AI_METRICS, UNITS } from '~/analytics/shared/constants';
import { BUCKETING_INTERVAL_ALL } from '~/analytics/shared/graphql/constants';
import { dasherize } from '~/lib/utils/text_utility';
import { formatNumber } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import FlowMetricsQuery from '~/analytics/shared/graphql/flow_metrics.query.graphql';
import { AI_IMPACT_TABLE_TRACKING_PROPERTY } from 'ee/analytics/analytics_dashboards/constants';
import VulnerabilitiesQuery from '../../graphql/vulnerabilities.query.graphql';
import AiMetricsQuery from '../graphql/ai_metrics.query.graphql';
import MergeRequestsQuery from '../../graphql/merge_requests.query.graphql';
import ContributorCountQuery from '../../graphql/contributor_count.query.graphql';
import { MERGE_REQUESTS_STATE_MERGED } from '../../graphql/constants';
import MetricLabel from '../../../analytics_dashboards/components/visualizations/data_table/metric_label.vue';
import TrendIndicator from '../../components/trend_indicator.vue';
import {
  SUPPORTED_DORA_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_CONTRIBUTOR_METRICS,
  SUPPORTED_MERGE_REQUEST_METRICS,
  SUPPORTED_FLOW_METRICS,
  DASHBOARD_LOADING_FAILURE,
  RESTRICTED_METRIC_ERROR,
  CHART_LOADING_FAILURE,
  CHART_GRADIENT,
  CHART_GRADIENT_INVERTED,
} from '../../constants';
import {
  mergeTableData,
  generateValueStreamDashboardStartDate,
  generateChartTimePeriods,
  generateSparklineCharts,
  getRestrictedTableMetrics,
  formatMetric,
} from '../../utils';
import {
  generateDateRanges,
  generateTableColumns,
  generateSkeletonTableData,
  generateTableRows,
  generateTableAlerts,
} from '../utils';
import {
  SUPPORTED_AI_METRICS,
  HIDE_METRIC_DRILL_DOWN,
  AI_IMPACT_TABLE_METRICS,
  AI_IMPACT_DATA_NOT_AVAILABLE_TOOLTIPS,
} from '../constants';
import {
  fetchMetricsForTimePeriods,
  extractGraphqlVulnerabilitiesData,
  extractGraphqlDoraData,
  extractGraphqlFlowData,
  extractGraphqlMergeRequestsData,
  extractGraphqlContributorCountData,
} from '../../api';
import { extractGraphqlAiData } from '../api';

export default {
  name: 'MetricTable',
  components: {
    GlTableLite,
    GlTooltip,
    GlSprintf,
    GlLink,
    GlSkeletonLoader,
    GlSparklineChart,
    MetricLabel,
    TrendIndicator,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin()],
  props: {
    namespace: {
      type: String,
      required: true,
    },
    isProject: {
      type: Boolean,
      required: true,
    },
    excludeMetrics: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      tableData: [],
    };
  },
  computed: {
    dashboardStartDate() {
      return generateValueStreamDashboardStartDate();
    },
    dashboardTimePeriods() {
      return generateDateRanges(this.dashboardStartDate);
    },
    chartTimePeriods() {
      return generateChartTimePeriods(this.dashboardStartDate);
    },
    dashboardTableFields() {
      return generateTableColumns(this.dashboardStartDate);
    },
    tableQueries() {
      return [
        { metrics: SUPPORTED_DORA_METRICS, queryFn: this.fetchDoraMetricsQuery },
        { metrics: SUPPORTED_FLOW_METRICS, queryFn: this.fetchFlowMetricsQuery },
        { metrics: SUPPORTED_AI_METRICS, queryFn: this.fetchAiMetricsQuery },
        { metrics: SUPPORTED_MERGE_REQUEST_METRICS, queryFn: this.fetchMergeRequestsMetricsQuery },
        {
          metrics: SUPPORTED_VULNERABILITY_METRICS,
          queryFn: this.fetchVulnerabilitiesMetricsQuery,
        },
        {
          metrics: SUPPORTED_CONTRIBUTOR_METRICS,
          queryFn: this.fetchContributorsCountQuery,
        },
      ].filter(({ metrics }) => !this.areAllMetricsSkipped(metrics));
    },
    duoRcaUsageRateEnabled() {
      return this.glFeatures?.duoRcaUsageRate;
    },
    restrictedMetrics() {
      return getRestrictedTableMetrics(this.excludeMetrics, this.glAbilities);
    },
    skippedMetrics() {
      return uniq([
        ...(!this.duoRcaUsageRateEnabled ? [AI_METRICS.DUO_RCA_USAGE_RATE] : []),
        ...this.restrictedMetrics,
        ...this.excludeMetrics,
      ]);
    },
  },
  async mounted() {
    const failedTableMetrics = await this.resolveQueries(this.fetchTableMetrics);
    const failedChartMetrics = await this.resolveQueries(this.fetchSparklineCharts);

    const alerts = generateTableAlerts([[RESTRICTED_METRIC_ERROR, this.restrictedMetrics]]);
    const warnings = generateTableAlerts([
      [DASHBOARD_LOADING_FAILURE, failedTableMetrics],
      [CHART_LOADING_FAILURE, failedChartMetrics],
    ]);

    if (alerts.length > 0 || warnings.length > 0) {
      this.$emit('set-alerts', { alerts, warnings, canRetry: warnings.length > 0 });
    }
  },
  created() {
    this.tableData = generateSkeletonTableData(this.skippedMetrics);
  },
  methods: {
    areAllMetricsSkipped(metrics) {
      return metrics.every((metric) => this.skippedMetrics.includes(metric));
    },

    rowAttributes({ metric: { identifier } }) {
      return {
        'data-testid': `ai-impact-metric-${dasherize(identifier)}`,
      };
    },

    requestPath(identifier) {
      return HIDE_METRIC_DRILL_DOWN.includes(identifier) ? '' : this.namespace;
    },

    trackingProperty(identifier) {
      return HIDE_METRIC_DRILL_DOWN.includes(identifier) ? '' : AI_IMPACT_TABLE_TRACKING_PROPERTY;
    },

    isValidTrend(value) {
      return typeof value === 'number' && value !== 0;
    },

    formatInvalidTrend(value) {
      return value === 0 ? formatMetric(0, UNITS.PERCENT) : value;
    },

    chartGradient(invert) {
      return invert ? CHART_GRADIENT_INVERTED : CHART_GRADIENT;
    },

    async resolveQueries(handler) {
      const result = await Promise.allSettled(this.tableQueries.map((query) => handler(query)));

      // Return an array of the failed metric IDs
      return result.reduce((failedMetrics, { reason = [] }) => failedMetrics.concat(reason), []);
    },

    async fetchTableMetrics({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(this.dashboardTimePeriods, queryFn);
        this.tableData = mergeTableData(this.tableData, generateTableRows(data));
      } catch (error) {
        throw metrics;
      }
    },

    async fetchSparklineCharts({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(this.chartTimePeriods, queryFn);
        this.tableData = mergeTableData(
          this.tableData,
          generateSparklineCharts(data, AI_IMPACT_TABLE_METRICS),
        );
      } catch (error) {
        throw metrics;
      }
    },

    async fetchDoraMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: DoraMetricsQuery,
        variables: {
          fullPath: this.namespace,
          interval: BUCKETING_INTERVAL_ALL,
          startDate,
          endDate,
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'dora',
      });
      return {
        ...timePeriod,
        ...extractGraphqlDoraData(responseData?.metrics || {}),
      };
    },

    async fetchFlowMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: FlowMetricsQuery,
        variables: {
          fullPath: this.namespace,
          startDate,
          endDate,
        },
      });

      const metrics = extractQueryResponseFromNamespace({ result, resultKey: 'flowMetrics' });
      return {
        ...timePeriod,
        ...extractGraphqlFlowData(metrics || {}),
      };
    },

    async fetchMergeRequestsMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: MergeRequestsQuery,
        variables: {
          fullPath: this.namespace,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
          state: MERGE_REQUESTS_STATE_MERGED,
        },
      });

      const metrics = extractQueryResponseFromNamespace({
        result,
        resultKey: 'mergeRequests',
      });
      return {
        ...timePeriod,
        ...extractGraphqlMergeRequestsData(metrics || {}),
      };
    },

    async fetchVulnerabilitiesMetricsQuery({ endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: VulnerabilitiesQuery,
        variables: {
          fullPath: this.namespace,

          // The vulnerabilities API request takes a date, so the timezone skews it outside the monthly range
          // The vulnerabilites count returns cumulative data for each day
          // we only want to use the value of the last day in the time period
          // so we override the startDate and set it to the same value as the end date
          startDate: toYmd(endDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'vulnerabilitiesCountByDay',
      });
      return {
        ...timePeriod,
        ...extractGraphqlVulnerabilitiesData(responseData?.nodes || []),
      };
    },

    async fetchContributorsCountQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: ContributorCountQuery,
        variables: {
          fullPath: this.namespace,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'contributors',
      });

      return {
        ...timePeriod,
        ...extractGraphqlContributorCountData(responseData || {}),
      };
    },

    async fetchAiMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: AiMetricsQuery,
        variables: {
          fullPath: this.namespace,
          startDate,
          endDate,
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'aiMetrics',
      });
      return {
        ...timePeriod,
        ...extractGraphqlAiData(responseData),
      };
    },
    formatNumber,
  },
  dataNotAvailableTooltips: AI_IMPACT_DATA_NOT_AVAILABLE_TOOLTIPS,
};
</script>
<template>
  <gl-table-lite
    :fields="dashboardTableFields"
    :items="tableData"
    table-class="gl-my-0 gl-table-fixed"
    :tbody-tr-attr="rowAttributes"
  >
    <template #head(change)="{ field: { label, description } }">
      <div class="gl-mb-2">{{ label }}</div>
      <div class="gl-font-normal">{{ description }}</div>
    </template>

    <template #cell(metric)="{ value: { identifier } }">
      <metric-label
        :identifier="identifier"
        :request-path="requestPath(identifier)"
        :is-project="isProject"
        :tracking-property="trackingProperty(identifier)"
      />
    </template>

    <template
      #cell()="{
        value: { value, tooltip },
        field: { key, end },
        item: {
          metric: { identifier },
        },
      }"
    >
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="50" />
      </span>
      <span v-else data-testid="ai-impact-table-value-cell">
        <span
          :ref="`${key}-${identifier}`"
          :class="{ 'gl-cursor-pointer hover:gl-underline': tooltip }"
          data-testid="formatted-metric-value"
        >
          {{ formatNumber(value) }}
        </span>

        <gl-tooltip v-if="tooltip" :target="() => $refs[`${key}-${identifier}`]">
          <gl-sprintf
            v-if="
              $options.dataNotAvailableTooltips[identifier] &&
              end < $options.dataNotAvailableTooltips[identifier].startDate
            "
            :message="$options.dataNotAvailableTooltips[identifier].message"
          >
            <template #link="{ content }">
              <gl-link :href="$options.dataNotAvailableTooltips[identifier].link" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
          <template v-else>{{ tooltip }}</template>
        </gl-tooltip>
      </span>
    </template>

    <template #cell(change)="{ value: { value, tooltip }, item: { invertTrendColor } }">
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="50" />
      </span>
      <trend-indicator
        v-else-if="isValidTrend(value)"
        :change="value"
        :invert-color="invertTrendColor"
      />
      <span
        v-else
        v-gl-tooltip="tooltip"
        :aria-label="tooltip"
        class="gl-cursor-pointer gl-text-sm gl-text-subtle hover:gl-underline"
        data-testid="metric-cell-no-change"
        tabindex="0"
      >
        {{ formatInvalidTrend(value) }}
      </span>
    </template>

    <template #cell(chart)="{ value: { data, tooltipLabel }, item: { invertTrendColor } }">
      <gl-sparkline-chart
        v-if="data"
        :height="30"
        :tooltip-label="tooltipLabel"
        :show-last-y-value="false"
        :data="data"
        :smooth="0.2"
        :gradient="chartGradient(invertTrendColor)"
        connect-nulls
      />
      <div v-else class="gl-py-4" data-testid="metric-chart-skeleton">
        <gl-skeleton-loader :lines="1" :width="100" />
      </div>
    </template>
  </gl-table-lite>
</template>
