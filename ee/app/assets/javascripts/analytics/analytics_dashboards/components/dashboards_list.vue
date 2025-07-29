<script>
import { GlLink, GlAlert, GlButton, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  getDashboardConfig,
  updateApolloCache,
} from 'ee/analytics/analytics_dashboards/utils/index';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { s__, __ } from '~/locale';
import { uniquifyString } from '~/lib/utils/text_utility';
import getAllCustomizableDashboardsQuery from '../graphql/queries/get_all_customizable_dashboards.query.graphql';
import getCustomizableDashboardQuery from '../graphql/queries/get_customizable_dashboard.query.graphql';
import { saveCustomDashboard } from '../api/dashboards_api';
import DashboardListItem from './list/dashboard_list_item.vue';

const productAnalyticsOnboardingType = 'productAnalytics';
const ONBOARDING_FEATURE_COMPONENTS = {
  [productAnalyticsOnboardingType]: () =>
    import('ee/product_analytics/onboarding/components/onboarding_list_item.vue'),
};

export default {
  name: 'DashboardsList',
  components: {
    PageHeading,
    GlButton,
    GlLink,
    GlAlert,
    GlSkeletonLoader,
    DashboardListItem,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    isProject: {
      type: Boolean,
    },
    isGroup: {
      type: Boolean,
    },
    customDashboardsProject: {
      type: Object,
      default: null,
    },
    canConfigureProjectSettings: {
      type: Boolean,
    },
    namespaceFullPath: {
      type: String,
    },
    features: {
      type: Array,
      default: () => [],
    },
    analyticsSettingsPath: {
      type: String,
    },
    canCreateNewDashboard: {
      type: Boolean,
    },
    customizableDashboardsAvailable: {
      type: Boolean,
    },
  },
  data() {
    return {
      requiresOnboarding: Object.keys(ONBOARDING_FEATURE_COMPONENTS),
      userDashboards: [],
      alert: null,
      loadingNewDashboard: false,
      promiseQueue: Promise.resolve(),
    };
  },
  computed: {
    showVizDesignerButton() {
      return this.isProject && this.customDashboardsProject && this.productAnalyticsIsOnboarded;
    },
    showUserActions() {
      return Boolean(this.canCreateNewDashboard);
    },
    dashboards() {
      return this.userDashboards;
    },
    isLoading() {
      return this.$apollo.queries.userDashboards.loading;
    },
    activeOnboardingComponents() {
      return Object.fromEntries(
        Object.entries(ONBOARDING_FEATURE_COMPONENTS)
          .filter(this.featureEnabled)
          .filter(this.featureRequiresOnboarding),
      );
    },
    showCustomDashboardSetupBanner() {
      return (
        this.customizableDashboardsAvailable &&
        !this.customDashboardsProject &&
        this.canConfigureProjectSettings
      );
    },
    productAnalyticsIsOnboarded() {
      return (
        this.featureEnabled([productAnalyticsOnboardingType]) &&
        !this.featureRequiresOnboarding([productAnalyticsOnboardingType])
      );
    },
  },
  mounted() {
    this.trackEvent('user_viewed_dashboard_list');
  },
  apollo: {
    userDashboards: {
      query: getAllCustomizableDashboardsQuery,
      variables() {
        return {
          fullPath: this.namespaceFullPath,
          isProject: this.isProject,
          isGroup: this.isGroup,
        };
      },
      update(data) {
        const namespaceData = this.isProject ? data.project : data.group;

        return namespaceData?.customizableDashboards?.nodes;
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  beforeDestroy() {
    this.alert?.dismiss();
  },
  methods: {
    featureEnabled([feature]) {
      return this.features.includes(feature);
    },
    featureRequiresOnboarding([feature]) {
      return this.requiresOnboarding.includes(feature);
    },
    onboardingComplete(feature) {
      this.requiresOnboarding = this.requiresOnboarding.filter((f) => f !== feature);

      this.$apollo.queries.userDashboards.refetch();
    },
    onError(error, captureError = true, message = '') {
      this.alert = createAlert({
        message: message || error.message,
        captureError,
        error,
      });
    },
    enqueuePromise(callback) {
      this.promiseQueue = this.promiseQueue.then(() => callback());
    },
    async fetchDashboardDetails(dashboardSlug) {
      const { data } = await this.$apollo.query({
        query: getCustomizableDashboardQuery,
        variables: {
          fullPath: this.namespaceFullPath,
          isProject: this.isProject,
          isGroup: this.isGroup,
          slug: dashboardSlug,
        },
      });

      const namespaceData = this.isProject ? data.project : data.group;
      const [dashboard] = namespaceData?.customizableDashboards?.nodes || [];

      return dashboard;
    },
    createDashboardClone(refDashboard) {
      const existingSlugs = this.dashboards.map(({ slug }) => slug);
      const existingTitles = this.dashboards.map(({ title }) => title);

      const newDashboardSlug = uniquifyString(refDashboard.slug, existingSlugs, '_copy');
      const newDashboardTitle = uniquifyString(
        refDashboard.title,
        existingTitles,
        ` ${__('(Copy)')}`,
      );

      return {
        ...refDashboard,
        slug: newDashboardSlug,
        title: newDashboardTitle,
        panels: refDashboard.panels.nodes,
        userDefined: true,
      };
    },
    updateDashboardCache(dashboard) {
      const apolloClient = this.$apollo.getClient();
      updateApolloCache({
        apolloClient,
        slug: dashboard.slug,
        dashboard,
        fullPath: this.namespaceFullPath,
        isProject: this.isProject,
        isGroup: this.isGroup,
      });
    },
    async onCloneDashboard(dashboardSlug) {
      // The commit API sometimes throws an error when handling concurrent requests
      // so we enqueue the cloning job to prevent that and filename conflicts.
      // Related issue: https://gitlab.com/gitlab-org/gitlab/-/issues/431398
      this.enqueuePromise(() => this.cloneDashboard(dashboardSlug));
    },
    async cloneDashboard(dashboardSlug) {
      try {
        this.loadingNewDashboard = true;

        const refDashboard = await this.fetchDashboardDetails(dashboardSlug);

        const newDashboard = this.createDashboardClone(refDashboard);

        const saveResult = await saveCustomDashboard({
          dashboardSlug: newDashboard.slug,
          dashboardConfig: getDashboardConfig(newDashboard),
          projectInfo: this.customDashboardsProject,
          isNewFile: true,
        });

        if (saveResult?.status !== HTTP_STATUS_CREATED) {
          throw new Error(`Bad save dashboard response. Status:${saveResult?.status}`);
        }

        this.alert?.dismiss();

        this.$toast.show(s__('Analytics|Dashboard was cloned successfully'));

        this.updateDashboardCache(newDashboard);
      } catch (error) {
        this.onError(
          error,
          true,
          s__('Analytics|Could not clone the dashboard. Refresh the page to try again.'),
        );
      } finally {
        this.loadingNewDashboard = false;
      }
    },
  },
  helpPageUrl: helpPagePath('user/analytics/analytics_dashboards'),
};
</script>

<template>
  <div>
    <page-heading :heading="s__('Analytics|Analytics dashboards')">
      <template #description>
        <template v-if="customizableDashboardsAvailable">
          {{
            isProject
              ? s__('Analytics|Dashboards are created by editing the projects dashboard files.')
              : s__('Analytics|Dashboards are created by editing the groups dashboard files.')
          }}
          <gl-link data-testid="help-link" :href="$options.helpPageUrl">{{
            __('Learn more.')
          }}</gl-link>
        </template>
        <template v-else>
          <gl-sprintf
            :message="
              s__(
                'Analytics|%{linkStart}Learn more%{linkEnd} about managing and interacting with analytics dashboards.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link data-testid="help-link" :href="$options.helpPageUrl">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
      </template>

      <template v-if="showVizDesignerButton || canCreateNewDashboard" #actions>
        <gl-button
          v-if="showVizDesignerButton"
          to="data-explorer"
          data-testid="data-explorer-button"
        >
          {{ s__('Analytics|Data explorer') }}
        </gl-button>
        <router-link
          v-if="canCreateNewDashboard"
          to="/new"
          class="btn btn-confirm btn-md gl-button"
          data-testid="new-dashboard-button"
        >
          {{ s__('Analytics|New dashboard') }}
        </router-link>
      </template>
    </page-heading>
    <gl-alert
      v-if="showCustomDashboardSetupBanner"
      :dismissible="false"
      :primary-button-text="s__('Analytics|Configure Dashboard Project')"
      :primary-button-link="analyticsSettingsPath"
      :title="s__('Analytics|Custom dashboards')"
      data-testid="configure-dashboard-container"
      class="gl-mb-6 gl-mt-3"
      >{{
        s__(
          'Analytics|To create your own dashboards, first configure a project to store your dashboards.',
        )
      }}</gl-alert
    >
    <ul data-testid="dashboards-list" class="content-list gl-border-t gl-border-subtle">
      <component
        :is="setupComponent"
        v-for="(setupComponent, feature) in activeOnboardingComponents"
        :key="feature"
        @complete="onboardingComplete(feature)"
        @error="onError"
      />

      <template v-if="isLoading">
        <li v-for="n in 2" :key="n" class="!gl-px-5">
          <gl-skeleton-loader :lines="2" />
        </li>
      </template>
      <dashboard-list-item
        v-for="dashboard in dashboards"
        v-else
        :key="dashboard.slug"
        :dashboard="dashboard"
        :show-user-actions="showUserActions"
        data-event-tracking="user_visited_dashboard"
        @clone="onCloneDashboard"
      />
      <li v-if="loadingNewDashboard" class="!gl-px-5">
        <gl-skeleton-loader :lines="2" />
      </li>
    </ul>
  </div>
</template>
