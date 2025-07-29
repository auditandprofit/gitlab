import Vue from 'vue';
import VueRouter from 'vue-router';
import { convertToSentenceCase } from '~/lib/utils/text_utility';
import { s__ } from '~/locale';
import ProductAnalyticsOnboardingView from 'ee/product_analytics/onboarding/onboarding_view.vue';
import ProductAnalyticsOnboardingSetup from 'ee/product_analytics/onboarding/onboarding_setup.vue';
import DashboardsList from './components/dashboards_list.vue';
import AnalyticsDashboard from './components/analytics_dashboard.vue';
import AnalyticsDataExplorer from './components/analytics_data_explorer.vue';

Vue.use(VueRouter);

export default (base, breadcrumbState, permissions = {}) => {
  return new VueRouter({
    mode: 'history',
    base,
    routes: [
      {
        name: 'index',
        path: '/',
        component: DashboardsList,
        meta: {
          getName: () => s__('Analytics|Analytics dashboards'),
          root: true,
        },
      },
      {
        name: 'data-explorer',
        path: '/data-explorer',
        component: AnalyticsDataExplorer,
        meta: {
          getName: () => s__('Analytics|Data explorer'),
        },
      },
      ...(permissions.canConfigureProjectSettings
        ? [
            {
              name: 'product-analytics-onboarding',
              path: '/product-analytics-onboarding',
              component: ProductAnalyticsOnboardingView,
              meta: {
                getName: () => s__('ProductAnalytics|Product analytics onboarding'),
              },
            },
            {
              name: 'instrumentation-detail',
              path: '/product-analytics-setup',
              component: ProductAnalyticsOnboardingSetup,
              meta: {
                getName: () => s__('ProductAnalytics|Product analytics onboarding'),
              },
            },
          ]
        : []),
      ...(permissions.canCreateNewDashboard
        ? [
            {
              name: 'dashboard-new',
              path: '/new',
              component: AnalyticsDashboard,
              props: {
                isNewDashboard: true,
              },
              meta: {
                getName: () => s__('Analytics|New dashboard'),
              },
            },
          ]
        : []),
      {
        name: 'dashboard-detail',
        path: '/:slug',
        component: AnalyticsDashboard,
        meta: {
          getName: () => convertToSentenceCase(breadcrumbState.name),
        },
      },
    ],
  });
};
