<script>
import { GlLink, GlSprintf } from '@gitlab/ui';

import DashboardHeader from '~/projects/pipelines/charts/components/dashboard_header.vue';
import { environmentTierDocumentationHref } from './static_data/shared';

export default {
  name: 'DoraChartHeader',
  components: {
    GlLink,
    GlSprintf,
    DashboardHeader,
  },
  props: {
    headerText: {
      type: String,
      required: true,
    },
    chartDescriptionText: {
      type: String,
      required: true,
    },
    chartDocumentationHref: {
      type: String,
      required: true,
    },
  },
  environmentTierDocumentationHref,
};
</script>
<template>
  <div>
    <dashboard-header>
      <template #default>
        {{ headerText }}
      </template>
      <template #description>
        <p data-testid="help-text">
          <gl-sprintf :message="chartDescriptionText">
            <template #link="{ content }">
              <gl-link :href="$options.environmentTierDocumentationHref" target="_blank"
                ><code>{{ content }}</code></gl-link
              >
            </template>
          </gl-sprintf>
          <gl-link :href="chartDocumentationHref" target="_blank">
            {{ __('Learn more.') }}
          </gl-link>
        </p>
      </template>
    </dashboard-header>
  </div>
</template>
