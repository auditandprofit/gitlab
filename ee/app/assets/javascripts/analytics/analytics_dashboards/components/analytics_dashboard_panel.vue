<script>
import { merge } from 'lodash';
import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import isString from 'lodash/isString';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { isEmptyPanelData } from '~/vue_shared/components/customizable_dashboard/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { VARIANT_DANGER, VARIANT_INFO, VARIANT_WARNING } from '~/alert';
import { HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import { __, s__, sprintf } from '~/locale';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import dataSources from '../data_sources';
import {
  PANEL_TROUBLESHOOTING_URL,
  VISUALIZATION_DOCUMENTATION_LINKS,
  VISUALIZATION_SLUG_DORA_PERFORMERS_SCORE,
  VISUALIZATION_SLUG_DORA_PROJECTS_COMPARISON,
  VISUALIZATION_SLUG_VSD_DORA_METRICS_TABLE,
  VISUALIZATION_SLUG_VSD_SECURITY_METRICS_TABLE,
} from '../constants';

export default {
  name: 'AnalyticsDashboardPanel',
  components: {
    ExtendedDashboardPanel,
    GlLink,
    GlSprintf,
    GlButton,
    AreaChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/area_chart.vue'),
    LineChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/line_chart.vue'),
    ColumnChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/column_chart.vue'),
    DataTable: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/data_table/data_table.vue'
      ),
    SingleStat: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/single_stat.vue'),
    DORAChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/dora_chart.vue'),
    UsageOverview: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/usage_overview.vue'),
    DoraPerformersScore: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/dora_performers_score.vue'
      ),
    DoraProjectsComparison: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/dora_projects_comparison.vue'
      ),
    AiImpactTable: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/ai_impact_table.vue'),
    ContributionsPushesChart: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_pushes_chart.vue'
      ),
    ContributionsMergeRequestsChart: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_merge_requests_chart.vue'
      ),
    ContributionsIssuesChart: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_issues_chart.vue'
      ),
    ContributionsByUserTable: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_by_user_table.vue'
      ),
    NamespaceMetadata: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/namespace_metadata.vue'),
    MergeRequestsThroughputTable: () =>
      import(
        'ee/analytics/analytics_dashboards/components/visualizations/merge_requests/throughput_table.vue'
      ),
  },
  mixins: [glAbilitiesMixin()],
  inject: [
    'namespaceId',
    'namespaceFullPath',
    'namespaceName',
    'isProject',
    'rootNamespaceName',
    'rootNamespaceFullPath',
    'dataSourceClickhouse',
    'overviewCountsAggregationEnabled',
  ],
  props: {
    visualization: {
      type: Object,
      required: true,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    queryOverrides: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    editing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const validationErrors = this.visualization?.errors;

    return {
      errors: [],
      warnings: [],
      alerts: [],
      alertTitle: '',
      alertDescription: '',
      alertDescriptionLink: '',
      validationErrors,
      canRetryError: false,
      data: null,
      loading: false,
      loadingDelayed: false,
      dropdownItems: [
        {
          text: __('Delete'),
          action: () => this.$emit('delete'),
          icon: 'remove',
        },
      ],
      currentRequestNumber: 0,
      visualizationOptionOverrides: {},
      visualizationQueryOverrides: {},
    };
  },
  computed: {
    hasValidationErrors() {
      return Boolean(this.validationErrors);
    },
    showEmptyState() {
      return !this.showAlertState && isEmptyPanelData(this.visualization.type, this.data);
    },
    alertVariant() {
      if (this.showLicenseRequiredState || this.errors.length > 0) return VARIANT_DANGER;
      if (this.warnings.length > 0) return VARIANT_WARNING;
      if (this.alerts.length > 0 || this.alertDescription.length) return VARIANT_INFO;
      return null;
    },
    isErrorAlert() {
      return this.alertVariant === VARIANT_DANGER;
    },
    showAlertState() {
      return (
        this.showLicenseRequiredState ||
        Boolean(this.alertMessages.length > 0 || this.alertDescription.length)
      );
    },
    alertMessages() {
      return [...this.errors, ...this.warnings, ...this.alerts].filter(this.isValidAlertMessage);
    },
    namespace() {
      return this.namespaceFullPath;
    },
    panelTitle() {
      return sprintf(this.title, {
        namespaceName: this.namespaceName,
        namespaceType: this.isProject ? __('project') : __('group'),
        namespaceFullPath: this.namespaceFullPath,
        rootNamespaceName: this.rootNamespaceName,
        rootNamespaceFullPath: this.rootNamespaceFullPath,
      });
    },
    visualizationOptions() {
      return merge({}, this.visualization.options, this.visualizationOptionOverrides);
    },
    aggregatedQueryOverrides() {
      return {
        ...this.queryOverrides,
        ...this.visualizationQueryOverrides,
      };
    },
    showLicenseRequiredState() {
      switch (this.visualization.slug) {
        case VISUALIZATION_SLUG_VSD_SECURITY_METRICS_TABLE:
          return !this.glAbilities?.readSecurityResource;
        case VISUALIZATION_SLUG_VSD_DORA_METRICS_TABLE:
        case VISUALIZATION_SLUG_DORA_PROJECTS_COMPARISON:
        case VISUALIZATION_SLUG_DORA_PERFORMERS_SCORE:
          return !this.glAbilities?.readDora4Analytics;
        default:
          return false;
      }
    },
    visualizationDocsLink() {
      return VISUALIZATION_DOCUMENTATION_LINKS[this.visualization.slug] || '';
    },
    bodyContentClasses() {
      return this.showLicenseRequiredState ? 'gl-content-center' : '';
    },
    tooltip() {
      return this.visualizationOptions?.tooltip;
    },
  },
  watch: {
    visualization: {
      handler: 'onVisualizationChange',
      immediate: true,
    },
    aggregatedQueryOverrides: 'fetchData',
    filters: 'fetchData',
  },
  methods: {
    async importDataSourceModule(dataType) {
      const module = await dataSources[dataType]();
      return module.default;
    },
    isValidAlertMessage(message) {
      return isString(message) || (isString(message.link) && isString(message.description));
    },
    onVisualizationChange() {
      if (this.hasValidationErrors) {
        this.setAlerts({
          errors: this.validationErrors,
          canRetry: false,
          title: s__('Analytics|Invalid visualization configuration'),
          description: s__(
            'Analytics|Something is wrong with your panel visualization configuration. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          ),
        });
        return;
      }

      this.fetchData();
    },
    onUpdateQuery(queryOverrides) {
      this.visualizationQueryOverrides = queryOverrides;
    },
    async fetchData() {
      const { aggregatedQueryOverrides, filters } = this;
      const { type: dataType, query } = this.visualization.data;
      this.loading = true;
      this.clearAlerts();
      const requestNumber = this.currentRequestNumber + 1;
      this.currentRequestNumber = requestNumber;

      try {
        const fetch = await this.importDataSourceModule(dataType);

        const data = await fetch({
          title: this.title,
          projectId: this.namespaceId,
          namespace: this.namespace,
          isProject: this.isProject,
          query,
          queryOverrides: aggregatedQueryOverrides,
          visualizationType: this.visualization.type,
          visualizationOptions: this.visualization.options,
          setAlerts: this.setAlerts,
          filters,
          onRequestDelayed: () => {
            this.loadingDelayed = true;
          },
          // NOTE: the `setVisualizationOverrides` callback allows us to update visualization options before render but after
          //       the data fetch, allowing us to include fetched data in the visualization options
          setVisualizationOverrides: ({ visualizationOptionOverrides = {} }) => {
            this.visualizationOptionOverrides = visualizationOptionOverrides;
          },
          dataSourceClickhouse: this.dataSourceClickhouse,
          overviewCountsAggregationEnabled: this.overviewCountsAggregationEnabled,
        });

        if (this.currentRequestNumber === requestNumber) {
          this.data = data;
        }
      } catch (error) {
        const isCubeJsBadRequest = this.isCubeJsBadRequest(error);
        const additionalErrorDetails = isCubeJsBadRequest ? error.response?.message : null;

        this.setAlerts({
          errors: [error, additionalErrorDetails].filter(Boolean),
          title: s__('Analytics|Failed to fetch data'),
          description: s__(
            'Analytics|Something went wrong while connecting to your data source. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          ),

          // bad or malformed CubeJS query, retry won't fix
          canRetry: !isCubeJsBadRequest,
        });
      } finally {
        this.loading = false;
        this.loadingDelayed = false;
      }
    },
    clearAlerts() {
      this.errors = [];
      this.warnings = [];
      this.alerts = [];
      this.alertDescription = '';
      this.descriptionLink = '';
      this.alertTitle = '';
    },
    setAlerts({
      errors = [],
      warnings = [],
      alerts = [],
      title = '',
      description = '',
      descriptionLink = '',
      canRetry = true,
    }) {
      this.canRetryError = canRetry;

      this.errors = errors;
      this.warnings = warnings;
      this.alerts = alerts;

      // Only capture in sentry when we are using the error/danger variant
      // Warning / Info variants do no correlate to errors
      errors.forEach((alert) => Sentry.captureException(alert));

      this.alertDescription = description;
      this.alertDescriptionLink = descriptionLink || this.$options.PANEL_TROUBLESHOOTING_URL;
      this.alertTitle = title;
    },
    isCubeJsBadRequest(error) {
      return Boolean(error.status === HTTP_STATUS_BAD_REQUEST && error.response?.message);
    },
  },
  PANEL_TROUBLESHOOTING_URL,
};
</script>

<template>
  <extended-dashboard-panel
    :title="panelTitle"
    :tooltip="tooltip"
    :loading="loading"
    :loading-delayed="loadingDelayed"
    :show-alert-state="showAlertState"
    :alert-variant="alertVariant"
    :alert-popover-title="alertTitle"
    :actions="dropdownItems"
    :editing="editing"
    :body-content-classes="bodyContentClasses"
  >
    <template #body>
      <div
        v-if="showLicenseRequiredState"
        class="gl-flex gl-items-center gl-justify-center"
        data-testid="dashboard-panel-license-warning"
      >
        <span>
          <gl-sprintf
            :message="
              __('This feature requires an Ultimate plan %{linkStart}Learn more%{linkEnd}.')
            "
          >
            <template #link="{ content }">
              <gl-link :href="visualizationDocsLink">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </span>
      </div>

      <span v-else-if="isErrorAlert" class="gl-text-subtle" data-testid="alert-body">
        {{ s__('Analytics|Something went wrong.') }}
      </span>

      <span v-else-if="showEmptyState" class="gl-text-subtle">
        {{ s__('Analytics|No results match your query or filter.') }}
      </span>

      <component
        :is="visualization.type"
        v-else
        class="gl-overflow-hidden"
        :data="data"
        :options="visualizationOptions"
        @set-alerts="setAlerts"
        @updateQuery="onUpdateQuery"
      />
    </template>

    <template #alert-popover>
      <gl-sprintf :message="alertDescription">
        <template #link="{ content }">
          <gl-link :href="alertDescriptionLink" class="gl-text-sm">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
      <ul v-if="alertMessages.length" data-testid="alert-messages" class="gl-mb-0">
        <li v-for="(message, i) in alertMessages" :key="`alert-message-${i}`">
          <span v-if="message.link && message.description">
            <gl-sprintf :message="message.description">
              <template #link="{ content }">
                <gl-link :href="message.link" class="gl-text-sm">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
          <span v-else>{{ message }}</span>
        </li>
      </ul>
      <gl-button v-if="canRetryError" class="gl-mt-3 gl-block" @click="fetchData">{{
        __('Retry')
      }}</gl-button>
    </template>
  </extended-dashboard-panel>
</template>
