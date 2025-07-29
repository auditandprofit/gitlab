<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters } from 'vuex';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { getDurationChart } from 'ee/api/analytics_api';
import { createAlert } from '~/alert';
import { transformFilters } from 'ee/analytics/shared/utils';
import { DEFAULT_RENAMED_FILTER_KEYS } from 'ee/analytics/shared/constants';
import {
  getDurationOverviewChartData,
  getDurationChartData,
  checkForDataError,
  alertErrorIfStatusNotOk,
  getValueStreamGraphQLId,
  getValueStreamStageGraphQLId,
} from '../../utils';
import getValueStreamStageMetricsQuery from '../../graphql/queries/get_value_stream_stage_metrics.query.graphql';
import OverviewChart from './overview_chart.vue';
import StageChart from './stage_chart.vue';
import StageScatterChart from './stage_scatter_chart.vue';

export default {
  name: 'DurationChartLoader',
  components: {
    OverviewChart,
    StageChart,
    StageScatterChart,
  },
  mixins: [glFeatureFlagsMixin()],
  data() {
    return {
      isLoading: false,
      durationData: [],
      errorMessage: '',
      stageMetricsItems: [],
      stageMetricsItemsPageInfo: {},
      isLoadingScatterChart: false,
      scatterChartErrorMessage: '',
    };
  },
  computed: {
    ...mapState(['selectedStage', 'createdAfter', 'createdBefore', 'namespace']),
    ...mapGetters([
      'isOverviewStageSelected',
      'activeStages',
      'cycleAnalyticsRequestParams',
      'namespaceRestApiRequestPath',
      'currentValueStreamId',
      'isProjectNamespace',
    ]),
    hasPlottableData() {
      return this.durationData.some(({ data }) => data.length);
    },
    overviewChartPlottableData() {
      return this.hasPlottableData ? getDurationOverviewChartData(this.durationData) : [];
    },
    stageChartPlottableData() {
      const { createdAfter, createdBefore, durationData, selectedStage } = this;
      const stageDurationData = durationData.find((stage) => stage.id === selectedStage.id);

      return stageDurationData?.data?.length
        ? getDurationChartData([stageDurationData], createdAfter, createdBefore)
        : [];
    },
    stageScatterChartEnabled() {
      return this.glFeatures?.vsaStageTimeScatterChart;
    },
    stageScatterChartPlottableData() {
      return this.stageMetricsItems.map(({ durationInMilliseconds, endEventTimestamp }) => [
        endEventTimestamp,
        durationInMilliseconds,
      ]);
    },
    stageScatterChartIssuableType() {
      const [stageMetricItem] = this.stageMetricsItems;
      const { record: { __typename } = {} } = stageMetricItem ?? {};

      return __typename;
    },
    shouldFetchScatterChartData() {
      return this.stageScatterChartEnabled && !this.isOverviewStageSelected;
    },
  },
  watch: {
    selectedStage() {
      this.fetchChartData();
    },
  },
  created() {
    this.fetchChartData();
  },
  methods: {
    fetchChartData() {
      if (this.shouldFetchScatterChartData) {
        this.initializeScatterChart();
      } else {
        this.fetchDurationData();
      }
    },
    fetchDurationData() {
      this.isLoading = true;
      this.errorMessage = '';

      Promise.all(
        this.activeStages.map(({ id, name }) => {
          return getDurationChart({
            stageId: id,
            namespacePath: this.namespaceRestApiRequestPath,
            valueStreamId: this.currentValueStreamId,
            params: this.cycleAnalyticsRequestParams,
          })
            .then(checkForDataError)
            .then(({ data }) => ({ id, name, selected: true, data }));
        }),
      )
        .then((data) => {
          this.durationData = data;
        })
        .catch((error) => {
          this.durationData = [];
          this.errorMessage = error.message;
          alertErrorIfStatusNotOk({
            error,
            message: __('There was an error while fetching value stream analytics duration data.'),
          });
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
    resetScatterChartData() {
      this.stageMetricsItems = [];
      this.stageMetricsItemsPageInfo = {};
    },
    async fetchScatterChartData(endCursor) {
      this.isLoadingScatterChart = true;

      const filters = transformFilters({
        filters: this.cycleAnalyticsRequestParams,
        renamedKeys: {
          labelName: 'labelNames',
          'not[labelName]': 'not[labelNames]',
          ...DEFAULT_RENAMED_FILTER_KEYS,
        },
        dropKeys: ['created_after', 'created_before', 'project_ids'],
      });

      try {
        const { data } = await this.$apollo.query({
          query: getValueStreamStageMetricsQuery,
          variables: {
            fullPath: this.namespace.path,
            isProject: this.isProjectNamespace,
            valueStreamId: getValueStreamGraphQLId(this.currentValueStreamId),
            stageId: getValueStreamStageGraphQLId(this.selectedStage.id),
            startDate: this.createdAfter,
            endDate: this.createdBefore,
            endCursor,
            ...filters,
          },
        });

        const namespaceType = this.isProjectNamespace ? 'project' : 'group';
        const { stages } = data?.[namespaceType]?.valueStreams?.nodes?.at(0) || {};
        const { edges = [], pageInfo } = stages?.at(0)?.metrics?.items || {};

        this.stageMetricsItems = [...this.stageMetricsItems, ...edges.map(({ node }) => node)];
        this.stageMetricsItemsPageInfo = pageInfo;

        if (pageInfo?.hasNextPage) {
          await this.fetchScatterChartData(pageInfo.endCursor);
        } else {
          this.isLoadingScatterChart = false;
        }
      } catch (error) {
        this.isLoadingScatterChart = false;
        this.scatterChartErrorMessage = error.message;

        createAlert({
          message: s__(
            'CycleAnalytics|There was an error while fetching data for the stage time chart.',
          ),
          error,
          captureError: true,
        });
      }
    },
    initializeScatterChart() {
      this.resetScatterChartData();
      this.fetchScatterChartData();
    },
  },
};
</script>
<template>
  <overview-chart
    v-if="isOverviewStageSelected"
    :is-loading="isLoading"
    :error-message="errorMessage"
    :plottable-data="overviewChartPlottableData"
  />
  <div v-else>
    <stage-scatter-chart
      v-if="stageScatterChartEnabled"
      :stage-title="selectedStage.title"
      :issuable-type="stageScatterChartIssuableType"
      :is-loading="isLoadingScatterChart"
      :plottable-data="stageScatterChartPlottableData"
      :error-message="scatterChartErrorMessage"
      :start-date="createdAfter"
      :end-date="createdBefore"
    />
    <stage-chart
      v-else
      :stage-title="selectedStage.title"
      :is-loading="isLoading"
      :error-message="errorMessage"
      :plottable-data="stageChartPlottableData"
    />
  </div>
</template>
