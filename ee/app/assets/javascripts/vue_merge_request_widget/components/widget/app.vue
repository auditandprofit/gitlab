<script>
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { n__ } from '~/locale';
import violationsCountQuery from 'ee/merge_requests/reports/queries/violations_count.query.graphql';
import CEWidgetApp from '~/vue_merge_request_widget/components/widget/app.vue';

export default {
  apollo: {
    violationsCount: {
      query: violationsCountQuery,
      variables() {
        return {
          iid: `${this.mr.iid}`,
          projectPath: this.mr.targetProjectFullPath,
        };
      },
      update: (d) => d.project?.mergeRequest?.policyViolations?.violationsCount,
      skip() {
        return this.glFeatures.mrReportsTab && !this.mr.hasPolicies;
      },
    },
  },
  components: {
    MrBrowserPerformanceWidget: () =>
      import('ee/vue_merge_request_widget/widgets/browser_performance/index.vue'),
    MrLoadPerformanceWidget: () =>
      import('ee/vue_merge_request_widget/widgets/load_performance/index.vue'),
    MrMetricsWidget: () => import('ee/vue_merge_request_widget/widgets/metrics/index.vue'),
    MrSecurityWidgetEE: () =>
      import('ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue'),
    MrSecurityWidgetCE: () =>
      import('~/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue'),
    MrStatusChecksWidget: () =>
      import('ee/vue_merge_request_widget/widgets/status_checks/index.vue'),
    MrLicenseComplianceWidget: () =>
      import('ee/vue_merge_request_widget/widgets/license_compliance/index.vue'),
  },
  extends: CEWidgetApp,
  mixins: [glFeatureFlagsMixin()],
  data() {
    return {
      violationsCount: null,
    };
  },
  computed: {
    licenseComplianceWidget() {
      if (!this.isViewingReport('license-compliance')) return undefined;

      return this.mr?.enabledReports?.licenseScanning ? 'MrLicenseComplianceWidget' : undefined;
    },

    browserPerformanceWidget() {
      if (!this.isViewingReport('browser-performance')) return undefined;

      return this.mr.browserPerformance ? 'MrBrowserPerformanceWidget' : undefined;
    },

    loadPerformanceWidget() {
      if (!this.isViewingReport('load-performance')) return undefined;

      return this.mr.loadPerformance ? 'MrLoadPerformanceWidget' : undefined;
    },

    metricsWidget() {
      if (!this.isViewingReport('metrics')) return undefined;

      return this.mr.metricsReportsPath ? 'MrMetricsWidget' : undefined;
    },

    statusChecksWidget() {
      if (!this.isViewingReport('status-checks')) return undefined;

      return this.mr.apiStatusChecksPath && !this.mr.isNothingToMergeState
        ? 'MrStatusChecksWidget'
        : undefined;
    },

    securityReportsWidget() {
      if (!this.isViewingReport('security-reports')) return undefined;

      return this.mr.canReadVulnerabilities ? 'MrSecurityWidgetEE' : 'MrSecurityWidgetCE';
    },
    // eslint-disable-next-line vue/no-unused-properties -- used by parent component CEWidgetApp render function
    widgets() {
      return [
        this.licenseComplianceWidget,
        this.codeQualityWidget,
        this.browserPerformanceWidget,
        this.loadPerformanceWidget,
        this.testReportWidget,
        this.metricsWidget,
        this.statusChecksWidget,
        this.terraformPlansWidget,
        this.securityReportsWidget,
        this.accessibilityWidget,
      ].filter((w) => w);
    },
    // eslint-disable-next-line vue/no-unused-properties -- overrides parent CEWidgetApp computed property
    collapsedSummaryText() {
      if (this.mr.hasPolicies && this.violationsCount !== null) {
        return n__('%d policy violations', '%d policy violations', this.violationsCount);
      }

      return CEWidgetApp.computed.collapsedSummaryText.call(this);
    },
    // eslint-disable-next-line vue/no-unused-properties -- overrides parent CEWidgetApp computed property
    statusIcon() {
      if (this.mr.hasPolicies && this.violationsCount !== null) {
        return this.violationsCount > 0 ? 'failed' : 'success';
      }

      return CEWidgetApp.computed.statusIcon.call(this);
    },
    // eslint-disable-next-line vue/no-unused-properties -- overrides parent CEWidgetApp computed property
    isLoadingSummary() {
      return (
        this.$apollo.queries.violationsCount.loading ||
        CEWidgetApp.computed.isLoadingSummary.call(this)
      );
    },
  },

  render: CEWidgetApp.render,
};
</script>
