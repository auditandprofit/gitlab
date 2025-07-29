<script>
import { GlTabs, GlTab, GlLink } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import DeploymentFrequencyCharts from 'ee/analytics/dora/components/deployment_frequency_charts.vue';
import LeadTimeCharts from 'ee/analytics/dora/components/lead_time_charts.vue';
import TimeToRestoreServiceCharts from 'ee/analytics/dora/components/time_to_restore_service_charts.vue';
import ChangeFailureRateCharts from 'ee/analytics/dora/components/change_failure_rate_charts.vue';
import MigrationAlert from 'ee/analytics/dora/components/migration_alert.vue';
import { mergeUrlParams, updateHistory, getParameterValues } from '~/lib/utils/url_utility';
import API from '~/api';
import ReleaseStatsCard from './release_stats_card.vue';

export default {
  name: 'CiCdAnalyticsApp',
  components: {
    ReleaseStatsCard,
    GlTabs,
    GlTab,
    GlLink,
    DeploymentFrequencyCharts,
    LeadTimeCharts,
    TimeToRestoreServiceCharts,
    ChangeFailureRateCharts,
    MigrationAlert,
  },
  releaseStatisticsTabEvent: 'g_analytics_ci_cd_release_statistics',
  deploymentFrequencyTabEvent: 'g_analytics_ci_cd_deployment_frequency',
  leadTimeTabEvent: 'g_analytics_ci_cd_lead_time',
  timeToRestoreServiceTabEvent: 'g_analytics_ci_cd_time_to_restore_service',
  changeFailureRateTabEvent: 'g_analytics_ci_cd_change_failure_rate',
  mixins: [glFeatureFlagsMixin()],
  inject: {
    groupPath: {
      type: String,
      default: '',
    },
    shouldRenderDoraCharts: {
      type: Boolean,
      default: false,
    },
    pipelineGroupUsageQuotaPath: {
      type: String,
      default: '',
    },
    canViewGroupUsageQuotaBoolean: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedTabIndex: 0,
    };
  },
  computed: {
    showDoraMetricsTabs() {
      return this.shouldRenderDoraCharts && !this.glFeatures.doraMetricsDashboard;
    },
    showDoraMetricsMigrationAlert() {
      return this.shouldRenderDoraCharts && this.glFeatures.doraMetricsDashboard;
    },
    tabs() {
      const tabsToShow = ['release-statistics'];

      if (this.showDoraMetricsTabs) {
        tabsToShow.push(
          'deployment-frequency',
          'lead-time',
          'time-to-restore-service',
          'change-failure-rate',
        );
      }

      tabsToShow.push('shared-runner-usage');

      return tabsToShow;
    },
    releaseStatsCardClasses() {
      return ['gl-mt-5'];
    },
  },
  created() {
    this.selectTab();
    window.addEventListener('popstate', this.selectTab);
  },
  methods: {
    selectTab() {
      const [tabQueryParam] = getParameterValues('tab');
      const tabIndex = this.tabs.indexOf(tabQueryParam);
      this.selectedTabIndex = tabIndex >= 0 ? tabIndex : 0;
    },
    onTabChange(newIndex) {
      if (newIndex !== this.selectedTabIndex) {
        this.selectedTabIndex = newIndex;
        const path = mergeUrlParams({ tab: this.tabs[newIndex] }, window.location.pathname);
        updateHistory({ url: path, title: window.title });
      }
    },
    trackTabClick(tab) {
      API.trackRedisHllUserEvent(tab);
    },
  },
};
</script>
<template>
  <div>
    <migration-alert v-if="showDoraMetricsMigrationAlert" :namespace-path="groupPath" />

    <gl-tabs v-if="tabs.length > 1" :value="selectedTabIndex" @input="onTabChange">
      <gl-tab
        :title="s__('CICDAnalytics|Release statistics')"
        data-testid="release-statistics-tab"
        @click="trackTabClick($options.releaseStatisticsTabEvent)"
      >
        <release-stats-card :class="releaseStatsCardClasses" />
      </gl-tab>
      <template v-if="showDoraMetricsTabs">
        <gl-tab
          :title="s__('CICDAnalytics|Deployment frequency')"
          data-testid="deployment-frequency-tab"
          @click="trackTabClick($options.deploymentFrequencyTabEvent)"
        >
          <deployment-frequency-charts />
        </gl-tab>
        <gl-tab
          :title="s__('CICDAnalytics|Lead time')"
          data-testid="lead-time-tab"
          @click="trackTabClick($options.leadTimeTabEvent)"
        >
          <lead-time-charts />
        </gl-tab>
        <gl-tab
          :title="s__('CICDAnalytics|Time to restore service')"
          data-testid="time-to-restore-service-tab"
          @click="trackTabClick($options.timeToRestoreServiceTabEvent)"
        >
          <time-to-restore-service-charts />
        </gl-tab>
        <gl-tab
          :title="s__('CICDAnalytics|Change failure rate')"
          data-testid="change-failure-rate-tab"
          @click="trackTabClick($options.changeFailureRateTabEvent)"
        >
          <change-failure-rate-charts />
        </gl-tab>
      </template>
      <template v-if="canViewGroupUsageQuotaBoolean" #tabs-end>
        <gl-link :href="pipelineGroupUsageQuotaPath" class="gl-ml-auto gl-self-center">{{
          __('View group pipeline usage quota')
        }}</gl-link>
      </template>
    </gl-tabs>
    <release-stats-card v-else :class="releaseStatsCardClasses" />
  </div>
</template>
