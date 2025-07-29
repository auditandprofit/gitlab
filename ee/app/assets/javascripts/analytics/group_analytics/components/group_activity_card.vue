<script>
import { GlSkeletonLoader, GlTooltipDirective } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/dist/charts';
import Api from 'ee/api';
import { createAlert } from '~/alert';
import { sprintf, __, s__ } from '~/locale';
import Tracking from '~/tracking';

const MERGE_REQUESTS_TRACKING_LABEL = 'g_analytics_activity_widget_mr_created_clicked';
const ISSUES_TRACKING_LABEL = 'g_analytics_activity_widget_issues_created_clicked';
const NEW_MEMBERS_TRACKING_LABEL = 'g_analytics_activity_widget_members_added_clicked';
const ACTIVITY_COUNT_LIMIT = 999;

export default {
  name: 'GroupActivityCard',
  components: {
    GlSkeletonLoader,
    GlSingleStat,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [Tracking.mixin()],
  inject: [
    'groupFullPath',
    'groupName',
    'mergeRequestsMetricLink',
    'issuesMetricLink',
    'newMembersMetricLink',
  ],
  data() {
    return {
      isLoading: false,
      metrics: {
        mergeRequests: {
          value: null,
          label: s__('GroupActivityMetrics|Merge requests created'),
          link: this.mergeRequestsMetricLink,
          trackingLabel: MERGE_REQUESTS_TRACKING_LABEL,
        },
        issues: {
          value: null,
          label: s__('GroupActivityMetrics|Issues created'),
          link: this.issuesMetricLink,
          trackingLabel: ISSUES_TRACKING_LABEL,
        },
        newMembers: {
          value: null,
          label: s__('GroupActivityMetrics|Members added'),
          link: this.newMembersMetricLink,
          trackingLabel: NEW_MEMBERS_TRACKING_LABEL,
        },
      },
    };
  },
  computed: {
    metricsArray() {
      return Object.entries(this.metrics).map(([key, obj]) => {
        const { value, label, link, trackingLabel } = obj;
        return {
          key,
          value,
          label,
          link,
          trackingLabel,
        };
      });
    },
  },
  created() {
    this.fetchMetrics(this.groupFullPath);
  },
  methods: {
    fetchMetrics(groupPath) {
      this.isLoading = true;

      return Promise.all([
        Api.groupActivityMergeRequestsCount(groupPath),
        Api.groupActivityIssuesCount(groupPath),
        Api.groupActivityNewMembersCount(groupPath),
      ])
        .then(([mrResponse, issuesResponse, newMembersResponse]) => {
          this.metrics.mergeRequests.value = mrResponse.data.merge_requests_count;
          this.metrics.issues.value = issuesResponse.data.issues_count;
          this.metrics.newMembers.value = newMembersResponse.data.new_members_count;
          this.isLoading = false;
        })
        .catch(() => {
          createAlert({
            message: __('Failed to load group activity metrics. Please try again.'),
          });
          this.isLoading = false;
        });
    },
    clampValue(value) {
      return value > ACTIVITY_COUNT_LIMIT ? '999+' : `${value}`;
    },
    tooltip(value) {
      return value > ACTIVITY_COUNT_LIMIT ? __('Results limit reached') : null;
    },
    clickMetric(trackingLabel) {
      this.track('click_button', { label: trackingLabel });
    },
  },
  activityTimeSpan: sprintf(__('Last %{days} days'), { days: 30 }),
};
</script>

<template>
  <div class="gl-mb-4 gl-mt-6 gl-flex gl-flex-col gl-items-start md:gl-flex-row">
    <div class="gl-flex gl-shrink-0 gl-flex-col gl-pr-9">
      <span class="gl-text-subtle">{{ s__('GroupActivityMetrics|Recent activity') }}</span>
      <span class="gl-font-bold gl-text-strong">{{ $options.activityTimeSpan }}</span>
    </div>
    <div
      v-for="{ key, value, label, link, trackingLabel } in metricsArray"
      :key="key"
      class="gl-my-4 gl-pr-9 md:gl-mb-0 md:gl-mt-0"
    >
      <gl-skeleton-loader v-if="isLoading" />
      <a
        v-else
        :href="link"
        class="gl-block gl-rounded-base !gl-no-underline hover:gl-bg-strong"
        data-testid="single-stat-link"
        @click="clickMetric(trackingLabel)"
      >
        <gl-single-stat
          v-gl-tooltip="tooltip(value)"
          :value="clampValue(value)"
          :title="label"
          :should-animate="true"
        />
      </a>
    </div>
  </div>
</template>
