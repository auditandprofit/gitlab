<script>
import { GlEmptyState } from '@gitlab/ui';

import { helpPagePath } from '~/helpers/help_page_helper';

import ProductAnalyticsGroupUsage from './group_usage/product_analytics_group_usage.vue';
import ProductAnalyticsProjectsUsage from './projects_usage/product_analytics_projects_usage.vue';

export default {
  name: 'ProductAnalyticsUsageQuotaApp',
  components: {
    GlEmptyState,
    ProductAnalyticsGroupUsage,
    ProductAnalyticsProjectsUsage,
  },
  inject: {
    productAnalyticsEnabled: {
      type: Boolean,
      required: true,
    },
    emptyStateIllustrationPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      showEmptyState: !this.productAnalyticsEnabled,
    };
  },
  methods: {
    handleNoProjects() {
      this.showEmptyState = true;
    },
  },
  ONBOARD_PROJECTS_URL: helpPagePath('/development/internal_analytics/product_analytics', {
    anchor: 'onboard-a-gitlab-project',
  }),
  ENABLE_PRODUCT_ANALYTICS_URL: helpPagePath('/development/internal_analytics/product_analytics', {
    anchor: 'enable-product-analytics',
  }),
};
</script>
<template>
  <section>
    <template v-if="showEmptyState">
      <gl-empty-state
        v-if="productAnalyticsEnabled"
        :svg-path="emptyStateIllustrationPath"
        :primary-button-text="s__('ProductAnalytics|Learn how to onboard projects')"
        :primary-button-link="$options.ONBOARD_PROJECTS_URL"
        :title="s__('ProductAnalytics|No projects found')"
        :description="
          s__(
            'ProductAnalytics|This group has no projects with product analytics onboarded in the current period.',
          )
        "
      />
      <gl-empty-state
        v-else
        :svg-path="emptyStateIllustrationPath"
        :primary-button-text="s__('ProductAnalytics|Learn how to enable product analytics')"
        :primary-button-link="$options.ENABLE_PRODUCT_ANALYTICS_URL"
        :title="s__('ProductAnalytics|Get started with product analytics')"
        :description="
          s__(
            `ProductAnalytics|Track your product's performance, and optimize your product and development processes.`,
          )
        "
      />
    </template>
    <template v-else>
      <product-analytics-group-usage @no-projects="handleNoProjects" />
      <product-analytics-projects-usage />
    </template>
  </section>
</template>
