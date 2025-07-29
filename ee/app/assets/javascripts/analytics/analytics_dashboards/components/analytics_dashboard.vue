<script>
import { GlEmptyState, GlSkeletonLoader, GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert, VARIANT_WARNING, VARIANT_DANGER } from '~/alert';
import { HTTP_STATUS_BAD_REQUEST, HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { __, s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import ProductAnalyticsFeedbackBanner from 'ee/analytics/dashboards/components/product_analytics_feedback_banner.vue';
import ValueStreamFeedbackBanner from 'ee/analytics/dashboards/components/value_stream_feedback_banner.vue';
import { saveCustomDashboard } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import { BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS } from 'ee/analytics/dashboards/constants';
import UsageOverviewBackgroundAggregationWarning from 'ee/analytics/dashboards/components/usage_overview_background_aggregation_warning.vue';
import UrlSync, {
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
} from '~/vue_shared/components/url_sync.vue';
import { updateApolloCache, getDashboardConfig, getUniquePanelId } from '../utils';
import {
  AI_IMPACT_DASHBOARD,
  BUILT_IN_VALUE_STREAM_DASHBOARD,
  FILE_ALREADY_EXISTS_SERVER_RESPONSE,
  NEW_DASHBOARD,
  CUSTOM_VALUE_STREAM_DASHBOARD,
  EVENT_LABEL_CREATED_DASHBOARD,
  EVENT_LABEL_EDITED_DASHBOARD,
  EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
  EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD,
  EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
  EVENT_LABEL_VIEWED_DASHBOARD,
  DEFAULT_DASHBOARD_LOADING_ERROR,
  DASHBOARD_REFRESH_MESSAGE,
} from '../constants';
import getAvailableVisualizations from '../graphql/queries/get_all_customizable_visualizations.query.graphql';
import getCustomizableDashboardQuery from '../graphql/queries/get_customizable_dashboard.query.graphql';
import {
  buildDefaultDashboardFilters,
  filtersToQueryParams,
  isDashboardFilterEnabled,
} from './filters/utils';
import AnalyticsCustomizableDashboard from './analytics_customizable_dashboard.vue';
import AnalyticsDashboardPanel from './analytics_dashboard_panel.vue';

export default {
  name: 'AnalyticsDashboard',
  components: {
    DateRangeFilter: () => import('./filters/date_range_filter.vue'),
    AnonUsersFilter: () => import('./filters/anon_users_filter.vue'),
    ProjectsFilter: () => import('./filters/projects_filter.vue'),
    FilteredSearchFilter: () => import('./filters/filtered_search_filter.vue'),
    AnalyticsCustomizableDashboard,
    AnalyticsDashboardPanel,
    ProductAnalyticsFeedbackBanner,
    ValueStreamFeedbackBanner,
    GlEmptyState,
    GlSkeletonLoader,
    GlAlert,
    UsageOverviewBackgroundAggregationWarning,
    GlLink,
    GlSprintf,
    UrlSync,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    customDashboardsProject: {
      type: Object,
      default: null,
    },
    customizableDashboardsAvailable: {
      type: Boolean,
    },
    namespaceFullPath: {
      type: String,
    },
    namespaceId: {
      type: String,
    },
    isProject: {
      type: Boolean,
    },
    isGroup: {
      type: Boolean,
    },
    dashboardEmptyStateIllustrationPath: {
      type: String,
    },
    breadcrumbState: {
      type: Object,
    },
    overviewCountsAggregationEnabled: {
      type: Boolean,
    },
  },
  async beforeRouteLeave(to, from, next) {
    if (!this.customizableDashboardsAvailable) {
      next();
      return;
    }

    const confirmed = await this.$refs.dashboard.confirmDiscardIfChanged();

    if (!confirmed) return;

    next();
  },
  props: {
    isNewDashboard: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      initialDashboard: null,
      showEmptyState: false,
      availableVisualizations: {
        loading: true,
        hasError: false,
        visualizations: [],
      },
      filters: null,
      isSaving: false,
      titleValidationError: null,
      backUrl: this.$router.resolve('/').href,
      changesSaved: false,
      alert: null,
      hasDashboardLoadError: false,
      savedPanels: null,
    };
  },
  computed: {
    currentDashboard() {
      return this.initialDashboard;
    },
    showValueStreamFeedbackBanner() {
      return [BUILT_IN_VALUE_STREAM_DASHBOARD, CUSTOM_VALUE_STREAM_DASHBOARD].includes(
        this.currentDashboard?.slug,
      );
    },
    showProductAnalyticsFeedbackBanner() {
      return (
        !this.currentDashboard?.userDefined &&
        BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS.includes(this.currentDashboard?.slug)
      );
    },
    showFilters() {
      return [
        this.showProjectsFilter,
        this.showAnonUserFilter,
        this.showDateRangeFilter,
        this.showFilteredSearchFilter,
      ].some(Boolean);
    },
    showDateRangeFilter() {
      return isDashboardFilterEnabled(this.dateRangeFilter);
    },
    showProjectsFilter() {
      return this.isGroup && isDashboardFilterEnabled(this.currentDashboard?.filters?.projects);
    },
    dateRangeFilter() {
      return this.currentDashboard?.filters?.dateRange || {};
    },
    dateRangeLimit() {
      return this.dateRangeFilter.numberOfDaysLimit || 0;
    },
    showAnonUserFilter() {
      return isDashboardFilterEnabled(this.currentDashboard?.filters?.excludeAnonymousUsers);
    },
    filteredSearchFilter() {
      return this.currentDashboard?.filters?.filteredSearch;
    },
    showFilteredSearchFilter() {
      return isDashboardFilterEnabled(this.filteredSearchFilter);
    },
    invalidDashboardErrors() {
      return this.currentDashboard?.errors ?? [];
    },
    hasDashboardError() {
      return this.hasDashboardLoadError || this.invalidDashboardErrors.length > 0;
    },
    dashboardHasUsageOverviewPanel() {
      return this.currentDashboard?.panels
        .map(({ visualization: { slug } }) => slug)
        .includes('usage_overview');
    },
    showEnableAggregationWarning() {
      return this.dashboardHasUsageOverviewPanel && !this.overviewCountsAggregationEnabled;
    },
    hasCustomDescriptionLink() {
      return this.isValueStreamsDashboard || this.isAiImpactDashboard;
    },
    isValueStreamsDashboard() {
      return this.currentDashboard.slug === BUILT_IN_VALUE_STREAM_DASHBOARD;
    },
    isAiImpactDashboard() {
      return this.currentDashboard.slug === AI_IMPACT_DASHBOARD;
    },
    editingEnabled() {
      return (
        this.customizableDashboardsAvailable &&
        this.currentDashboard.userDefined &&
        this.currentDashboard.slug !== CUSTOM_VALUE_STREAM_DASHBOARD
      );
    },
    queryParams() {
      return filtersToQueryParams(this.filters);
    },
    dateRangeOptions() {
      return this.currentDashboard.filters?.dateRange?.options;
    },
    filteredSearchOptions() {
      return this.currentDashboard.filters?.filteredSearch?.options;
    },
  },
  watch: {
    initialDashboard({ title: label, userDefined } = {}) {
      this.trackEvent(EVENT_LABEL_VIEWED_DASHBOARD, {
        ...(!this.isNewDashboard && { label }),
      });

      this.filters = buildDefaultDashboardFilters(
        window.location.search,
        this.currentDashboard.filters,
      );

      if (userDefined) {
        this.trackEvent(EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD, {
          ...(!this.isNewDashboard && { label }),
        });
      } else {
        this.trackEvent(EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD, {
          label,
        });
      }
    },
  },
  async created() {
    if (this.isNewDashboard) {
      this.initialDashboard = this.createNewDashboard();
    }
  },
  beforeDestroy() {
    this.alert?.dismiss();

    // Clear the breadcrumb name when we leave this component so it doesn't
    // flash the wrong name when a user views a different dashboard
    this.breadcrumbState.updateName('');
  },
  apollo: {
    initialDashboard: {
      query: getCustomizableDashboardQuery,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          slug: this.$route?.params.slug,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      skip() {
        return this.isNewDashboard;
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;
        const [dashboard] = namespaceData?.customizableDashboards?.nodes || [];

        if (!dashboard) {
          this.showEmptyState = true;
          return null;
        }

        return {
          ...dashboard,
          panels: this.getDashboardPanels(dashboard),
        };
      },
      result() {
        this.breadcrumbState.updateName(this.initialDashboard?.title || '');

        this.validateFilters(this.initialDashboard?.filters);
      },
      error(error) {
        const message = [
          error.message || DEFAULT_DASHBOARD_LOADING_ERROR,
          DASHBOARD_REFRESH_MESSAGE,
        ].join('. ');

        this.showError({
          error,
          capture: true,
          title: s__('Analytics|Failed to load dashboard'),
          message,
          messageLinks: {
            link: this.$options.troubleshootingUrl,
          },
        });
        this.hasDashboardLoadError = true;
      },
    },
    availableVisualizations: {
      query: getAvailableVisualizations,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      skip() {
        return !this.initialDashboard || !this.initialDashboard?.userDefined;
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;
        const visualizations = namespaceData?.customizableDashboardVisualizations?.nodes || [];
        return {
          loading: false,
          hasError: false,
          visualizations,
        };
      },
      error(error) {
        this.availableVisualizations = {
          loading: false,
          hasError: true,
          visualizations: [],
        };

        Sentry.captureException(error);
      },
    },
  },
  methods: {
    createNewDashboard() {
      return NEW_DASHBOARD();
    },
    getDashboardPanels(dashboard) {
      // Panel ids need to remain consistent and they are unique to the
      // frontend. Thus they don't get saved with GraphQL and we need to
      // reference the saved panels array to persist the ids.
      if (this.savedPanels) return this.savedPanels;

      const panels = dashboard.panels?.nodes || [];

      return panels.map(({ id, ...panel }) => ({
        ...panel,
        id: getUniquePanelId(),
      }));
    },
    async saveDashboard(dashboardSlug, dashboard) {
      this.validateDashboardTitle(dashboard.title, true);
      if (this.titleValidationError) {
        return;
      }

      try {
        this.changesSaved = false;
        this.isSaving = true;
        const saveResult = await saveCustomDashboard({
          dashboardSlug,
          dashboardConfig: getDashboardConfig(dashboard),
          projectInfo: this.customDashboardsProject,
          isNewFile: this.isNewDashboard,
        });

        if (saveResult?.status === HTTP_STATUS_CREATED) {
          this.alert?.dismiss();

          this.$toast.show(s__('Analytics|Dashboard was saved successfully'));

          if (this.isNewDashboard) {
            this.trackEvent(EVENT_LABEL_CREATED_DASHBOARD, {
              label: dashboard.title,
            });
          } else {
            this.trackEvent(EVENT_LABEL_EDITED_DASHBOARD, {
              label: dashboard.title,
            });
          }

          const apolloClient = this.$apollo.getClient();
          updateApolloCache({
            apolloClient,
            slug: dashboardSlug,
            dashboard,
            fullPath: this.namespaceFullPath,
            isProject: this.isProject,
            isGroup: this.isGroup,
          });

          this.savedPanels = dashboard.panels;

          if (this.isNewDashboard) {
            // We redirect now to the new route
            this.$router.push({
              name: 'dashboard-detail',
              params: { slug: dashboardSlug },
            });
          }

          this.changesSaved = true;
        } else {
          throw new Error(`Bad save dashboard response. Status:${saveResult?.status}`);
        }
      } catch (error) {
        const { message = '' } = error?.response?.data || {};

        if (message === FILE_ALREADY_EXISTS_SERVER_RESPONSE) {
          this.titleValidationError = s__('Analytics|A dashboard with that name already exists.');
        } else if (error.response?.status === HTTP_STATUS_BAD_REQUEST) {
          // We can assume bad request errors are a result of user error.
          // We don't need to capture these errors and can render the message to the user.
          this.showError({ error, capture: false, message: error.response?.data?.message });
        } else {
          this.showError({ error, capture: true });
        }
      } finally {
        this.isSaving = false;
      }
    },
    showError({ error, capture, message, messageLinks, title = '', variant = VARIANT_DANGER }) {
      this.alert = createAlert({
        variant,
        title,
        message: message || s__('Analytics|Error while saving dashboard'),
        messageLinks,
        error,
        captureError: capture,
      });
    },
    validateDashboardTitle(newTitle, submitting) {
      if (this.titleValidationError !== null || submitting) {
        this.titleValidationError = newTitle?.length > 0 ? '' : __('This field is required.');
      }
    },
    validateFilters(filters = {}) {
      if (filters?.dateRange?.enabled && filters?.dateRange.defaultOption) {
        const {
          dateRange: { defaultOption, options = [] },
        } = filters;
        if (!options.includes(defaultOption)) {
          this.showError({
            title: this.$options.i18n.dateRangeFilterValidationTitle,
            variant: VARIANT_WARNING,
            message: sprintf(this.$options.i18n.dateRangeFilterValidationMessage, {
              defaultOption,
            }),
          });
        }
      }
    },
    panelTestId({ visualization: { slug = '' } }) {
      return `panel-${slug.replaceAll('_', '-')}`;
    },
    setDateRangeFilter({ dateRangeOption, startDate, endDate }) {
      this.filters = {
        ...this.filters,
        dateRangeOption,
        startDate,
        endDate,
      };
    },
    setAnonymousUsersFilter(filterAnonUsers) {
      this.filters = {
        ...this.filters,
        filterAnonUsers,
      };

      if (filterAnonUsers) {
        this.trackEvent(EVENT_LABEL_EXCLUDE_ANONYMISED_USERS);
      }
    },
    setProjectsFilter(project) {
      this.filters = {
        ...this.filters,
        projectFullPath: project?.fullPath || null,
      };
    },
    setFilteredSearchFilter(searchFilters) {
      this.filters = {
        ...this.filters,
        searchFilters,
      };
    },
  },
  troubleshootingUrl: helpPagePath('user/analytics/analytics_dashboards', {
    anchor: '#troubleshooting',
  }),
  i18n: {
    aiImpactDescriptionLink: s__(
      'Analytics|Learn more about %{docsLinkStart}AI impact analytics%{docsLinkEnd} and %{subscriptionLinkStart}GitLab Duo seats%{subscriptionLinkEnd}.',
    ),
    dateRangeFilterValidationTitle: __('Date range filter validation'),
    dateRangeFilterValidationMessage: s__(
      "Analytics|Default date range '%{defaultOption}' is not included in the list of dateRange options",
    ),
  },
  VSD_DOCUMENTATION_LINK: helpPagePath('user/analytics/value_streams_dashboard'),
  AI_IMPACT_DOCUMENTATION_LINK: helpPagePath('user/analytics/ai_impact_analytics'),
  DUO_PRO_SUBSCRIPTION_ADD_ON_LINK: helpPagePath('subscriptions/subscription-add-ons'),
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
};
</script>

<template>
  <div>
    <template v-if="currentDashboard">
      <gl-alert
        v-if="invalidDashboardErrors.length > 0"
        data-testid="analytics-dashboard-invalid-config-alert"
        class="gl-mt-4"
        :title="s__('Analytics|Invalid dashboard configuration')"
        :primary-button-text="__('Learn more')"
        :primary-button-link="$options.troubleshootingUrl"
        :dismissible="false"
        variant="danger"
      >
        <ul class="gl-m-0">
          <li v-for="errorMessage in invalidDashboardErrors" :key="errorMessage">
            {{ errorMessage }}
          </li>
        </ul>
      </gl-alert>
      <value-stream-feedback-banner v-if="showValueStreamFeedbackBanner" />
      <product-analytics-feedback-banner v-if="showProductAnalyticsFeedbackBanner" />

      <analytics-customizable-dashboard
        ref="dashboard"
        :initial-dashboard="currentDashboard"
        :available-visualizations="availableVisualizations"
        :is-saving="isSaving"
        :is-new-dashboard="isNewDashboard"
        :changes-saved="changesSaved"
        :title-validation-error="titleValidationError"
        :editing-enabled="editingEnabled"
        @save="saveDashboard"
        @title-input="validateDashboardTitle"
      >
        <!-- TODO: Remove this link in https://gitlab.com/gitlab-org/gitlab/-/issues/465569 -->
        <template v-if="hasCustomDescriptionLink" #after-description>
          <span data-testid="after-description-link">
            <gl-sprintf v-if="isAiImpactDashboard" :message="$options.i18n.aiImpactDescriptionLink">
              <template #docsLink="{ content }">
                <gl-link :href="$options.AI_IMPACT_DOCUMENTATION_LINK">{{ content }}</gl-link>
              </template>
              <template #subscriptionLink="{ content }">
                <gl-link :href="$options.DUO_PRO_SUBSCRIPTION_ADD_ON_LINK">{{ content }}</gl-link>
              </template>
            </gl-sprintf>

            <gl-sprintf
              v-else-if="isValueStreamsDashboard"
              :message="__('%{linkStart} Learn more%{linkEnd}.')"
            >
              <template #link="{ content }">
                <gl-link :href="$options.VSD_DOCUMENTATION_LINK">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
        </template>

        <template #alert>
          <div v-if="showEnableAggregationWarning" class="gl-mx-3">
            <usage-overview-background-aggregation-warning />
          </div>
        </template>

        <template v-if="showFilters" #filters>
          <filtered-search-filter
            v-if="showFilteredSearchFilter"
            class="gl-basis-full"
            :initial-filter-value="filters.searchFilters"
            :options="filteredSearchOptions"
            @change="setFilteredSearchFilter"
          />
          <projects-filter
            v-if="showProjectsFilter"
            :group-namespace="namespaceFullPath"
            @projectSelected="setProjectsFilter"
          />
          <date-range-filter
            v-if="showDateRangeFilter"
            :default-option="filters.dateRangeOption"
            :start-date="filters.startDate"
            :end-date="filters.endDate"
            :date-range-limit="dateRangeLimit"
            :options="dateRangeOptions"
            @change="setDateRangeFilter"
          />
          <anon-users-filter
            v-if="showAnonUserFilter"
            :value="filters.filterAnonUsers"
            @change="setAnonymousUsersFilter"
          />
          <url-sync
            :query="queryParams"
            :url-params-update-strategy="$options.URL_SET_PARAMS_STRATEGY"
            :history-update-method="$options.HISTORY_REPLACE_UPDATE_METHOD"
          />
        </template>

        <template #panel="{ panel, editing, deletePanel }">
          <analytics-dashboard-panel
            :title="panel.title"
            :visualization="panel.visualization"
            :query-overrides="panel.queryOverrides || undefined"
            :filters="filters"
            :editing="editing"
            :data-testid="panelTestId(panel)"
            @delete="deletePanel"
          />
        </template>
      </analytics-customizable-dashboard>
    </template>
    <gl-empty-state
      v-else-if="showEmptyState"
      :svg-path="dashboardEmptyStateIllustrationPath"
      :title="s__('Analytics|Dashboard not found')"
      :description="s__('Analytics|No dashboard matches the specified URL path.')"
      :primary-button-text="s__('Analytics|View available dashboards')"
      :primary-button-link="backUrl"
    />
    <div v-else-if="!hasDashboardError" class="gl-mt-7">
      <gl-skeleton-loader />
    </div>
  </div>
</template>
