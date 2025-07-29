<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';

import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { nMonthsBefore } from '~/lib/utils/datetime/date_calculation_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

import { projectHasProductAnalyticsEnabled } from '../../utils';
import getGroupProductAnalyticsUsage from '../../graphql/queries/get_group_product_analytics_usage.query.graphql';
import { findCurrentMonthEventsUsed, getCurrentMonth, mapMonthlyTotals } from '../utils';
import ProductAnalyticsGroupUsageOverview from './product_analytics_group_usage_overview.vue';
import ProductAnalyticsGroupMonthlyUsageChart from './product_analytics_group_monthly_usage_chart.vue';

export default {
  name: 'ProductAnalyticsGroupUsage',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    ProductAnalyticsGroupMonthlyUsageChart,
    ProductAnalyticsGroupUsageOverview,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    namespacePath: {
      type: String,
    },
  },
  data() {
    return {
      error: null,
      monthlyTotals: null,
      storedEventsLimit: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.monthlyTotals.loading;
    },
    showUsageOverview() {
      return this.glFeatures.productAnalyticsBilling;
    },
    eventsUsed() {
      return findCurrentMonthEventsUsed(this.monthlyTotals);
    },
  },
  apollo: {
    monthlyTotals: {
      query: getGroupProductAnalyticsUsage,
      variables() {
        return {
          namespacePath: this.namespacePath,
          monthSelection: this.getMonthsToQuery(),
        };
      },
      update(data) {
        const projects = data.group.projects.nodes.filter(projectHasProductAnalyticsEnabled);

        this.storedEventsLimit = data.group.productAnalyticsStoredEventsLimit;

        if (projects.length === 0) {
          this.$emit('no-projects');
          return [];
        }

        return mapMonthlyTotals(projects);
      },
      error(error) {
        this.error = error;
        Sentry.captureException(error);
      },
    },
  },
  methods: {
    getMonthsToQuery() {
      // 12 months data will cause backend performance issues for some large groups. So we can toggle
      // this when needed until performance is improved in https://gitlab.com/gitlab-org/gitlab/-/issues/430865
      const ONE_YEAR = 12;
      const TWO_MONTHS = 2;
      const numMonthsDataToFetch = this.glFeatures.productAnalyticsUsageQuotaAnnualData
        ? ONE_YEAR
        : TWO_MONTHS;

      const currentMonth = getCurrentMonth();
      return Array.from({ length: numMonthsDataToFetch }).map((_, index) => {
        const date = nMonthsBefore(currentMonth, index);

        // note: JS `getMonth()` is 0 based, so add 1
        return { year: date.getFullYear(), month: date.getMonth() + 1 };
      });
    },
  },
  USAGE_QUOTA_LEARN_MORE_URL: helpPagePath('/development/internal_analytics/product_analytics', {
    anchor: 'view-product-analytics-usage-quota',
  }),
  DATA_RETENTION_LEARN_MORE_URL: helpPagePath('/development/internal_analytics/product_analytics', {
    anchor: 'product-analytics-provider',
  }),
};
</script>
<template>
  <section class="gl-mb-7 gl-mt-5">
    <h2>{{ s__('Analytics|Overview') }}</h2>
    <p>
      <gl-sprintf
        :message="
          s__(
            'ProductAnalytics|Product analytics usage is calculated based on the total number of events received from projects within the group. Contact your account manager if you need additional event quota. %{usageQuotaLinkStart}Learn more%{usageQuotaLinkEnd}. If GitLab manages your cluster, then GitLab retains your analytics data for 1 year. %{dataRetentionLinkStart}Learn more about data retention policy%{dataRetentionLinkEnd}.',
          )
        "
      >
        <template #usageQuotaLink="{ content }">
          <gl-link
            :href="$options.USAGE_QUOTA_LEARN_MORE_URL"
            data-testid="product-analytics-usage-quota-learn-more"
            >{{ content }}</gl-link
          >
        </template>
        <template #dataRetentionLink="{ content }">
          <gl-link
            :href="$options.DATA_RETENTION_LEARN_MORE_URL"
            data-testid="product-analytics-data-retention-learn-more"
            >{{ content }}</gl-link
          >
        </template>
      </gl-sprintf>
    </p>

    <gl-alert v-if="error" variant="danger" :dismissible="false">
      {{
        s__(
          'ProductAnalytics|Something went wrong while loading product analytics usage data. Refresh the page to try again.',
        )
      }}
    </gl-alert>
    <template v-else>
      <product-analytics-group-usage-overview
        v-if="showUsageOverview"
        :events-used="eventsUsed"
        :stored-events-limit="storedEventsLimit"
        :is-loading="isLoading"
      />

      <h2>{{ s__('Analytics|Usage breakdown') }}</h2>
      <product-analytics-group-monthly-usage-chart
        :is-loading="isLoading"
        :monthly-totals="monthlyTotals"
      />
    </template>
  </section>
</template>
