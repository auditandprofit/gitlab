<script>
import { unescape } from 'lodash';
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { sanitize } from '~/lib/dompurify';
import { joinPaths } from '~/lib/utils/url_utility';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';

const DORA_METRICS_DASHBOARD_SLUG = 'dora_metrics';

export default {
  name: 'MigrationAlert',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
    UserCalloutDismisser,
  },
  props: {
    namespacePath: {
      type: String,
      required: true,
    },
    isProject: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    dashboardsLink() {
      return joinPaths(
        gon.relative_url_root || '',
        '/',
        this.isProject ? this.namespacePath : `groups/${this.namespacePath}`,
        '/-/analytics/dashboards',
      );
    },
    doraMetricsLink() {
      return joinPaths(this.dashboardsLink, DORA_METRICS_DASHBOARD_SLUG);
    },
    userCalloutFeatureName() {
      return this.isProject ? 'dora_dashboard_migration_project' : 'dora_dashboard_migration_group';
    },
  },
  i18n: {
    title: s__('DORA4Metrics|Looking for DORA metrics?'),
    message: unescape(
      sanitize(
        s__(
          'DORA4Metrics|DORA metrics have moved to %{dashboardsLinkStart}Analytics dashboards%{dashboardsLinkEnd} &gt; %{doraMetricsLinkStart}DORA metrics%{doraMetricsLinkEnd}.',
        ),
        { ALLOWED_TAGS: [] },
      ),
    ),
  },
};
</script>
<template>
  <user-callout-dismisser :feature-name="userCalloutFeatureName">
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-alert
        v-if="shouldShowCallout"
        :title="$options.i18n.title"
        class="gl-mb-4"
        @dismiss="dismiss"
      >
        <gl-sprintf :message="$options.i18n.message">
          <template #dashboardsLink="{ content }">
            <gl-link data-testid="dashboardsLink" variant="unstyled" :href="dashboardsLink">{{
              content
            }}</gl-link>
          </template>
          <template #doraMetricsLink="{ content }">
            <gl-link data-testid="doraMetricsLink" variant="unstyled" :href="doraMetricsLink">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </gl-alert>
    </template>
  </user-callout-dismisser>
</template>
