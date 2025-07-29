<script>
import { GlBadge, GlButton, GlIcon, GlLink, GlPopover } from '@gitlab/ui';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import { historyPushState } from '~/lib/utils/common_utils';
import MrWidget from '~/vue_merge_request_widget/components/widget/widget.vue';
import MrWidgetRow from '~/vue_merge_request_widget/components/widget/widget_content_row.vue';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import { capitalizeFirstCharacter, convertToCamelCase } from '~/lib/utils/text_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import { DynamicScroller, DynamicScrollerItem } from 'vendor/vue-virtual-scroller';
import SummaryText, { MAX_NEW_VULNERABILITIES } from './summary_text.vue';
import SecurityTrainingPromoWidget from './security_training_promo_widget.vue';
import { i18n, popovers, reportTypes } from './i18n';

export default {
  name: 'WidgetSecurityReports',
  components: {
    VulnerabilityFindingModal: () =>
      import('ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue'),
    MrWidget,
    MrWidgetRow,
    SummaryText,
    SummaryHighlights,
    SecurityTrainingPromoWidget,
    GlBadge,
    GlButton,
    GlIcon,
    GlLink,
    GlPopover,
    DynamicScroller,
    DynamicScrollerItem,
  },
  mixins: [glAbilitiesMixin()],
  i18n,
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isLoading: true,
      hasAtLeastOneReportWithMaxNewVulnerabilities: false,
      modalData: null,
      topLevelErrorMessage: '',
      collapsedData: {},
    };
  },
  computed: {
    reports() {
      return this.endpoints
        .map(([, reportType]) => this.collapsedData[reportType])
        .filter((r) => r);
    },

    helpPopovers() {
      return {
        SAST: {
          options: { title: popovers.SAST_TITLE },
          content: { text: popovers.SAST_TEXT, learnMorePath: this.mr.sastHelp },
        },
        DAST: {
          options: { title: popovers.DAST_TITLE },
          content: { text: popovers.DAST_TEXT, learnMorePath: this.mr.dastHelp },
        },
        SECRET_DETECTION: {
          options: { title: popovers.SECRET_DETECTION_TITLE },
          content: {
            text: popovers.SECRET_DETECTION_TEXT,
            learnMorePath: this.mr.secretDetectionHelp,
          },
        },
        CONTAINER_SCANNING: {
          options: { title: popovers.CONTAINER_SCANNING_TITLE },
          content: {
            text: popovers.CONTAINER_SCANNING_TEXT,
            learnMorePath: this.mr.containerScanningHelp,
          },
        },
        DEPENDENCY_SCANNING: {
          options: { title: popovers.DEPENDENCY_SCANNING_TITLE },
          content: {
            text: popovers.DEPENDENCY_SCANNING_TEXT,
            learnMorePath: this.mr.dependencyScanningHelp,
          },
        },
        API_FUZZING: {
          options: { title: popovers.API_FUZZING_TITLE },
          content: {
            learnMorePath: this.mr.apiFuzzingHelp,
          },
        },
        COVERAGE_FUZZING: {
          options: { title: popovers.COVERAGE_FUZZING_TITLE },
          content: {
            learnMorePath: this.mr.coverageFuzzingHelp,
          },
        },
      };
    },

    isCollapsible() {
      return this.vulnerabilitiesCount > 0;
    },

    vulnerabilitiesCount() {
      return this.reports.reduce((counter, current) => {
        return counter + current.numberOfNewFindings + (current.fixed?.length || 0);
      }, 0);
    },

    highlights() {
      if (!this.reports.length) {
        return {};
      }

      const highlights = {
        [HIGH]: 0,
        [CRITICAL]: 0,
        other: 0,
      };

      // The data we receive from the API is something like:
      // [
      //  { scanner: "SAST", added: [{ id: 15, severity: 'critical' }] },
      //  { scanner: "DAST", added: [{ id: 15, severity: 'high' }] },
      //  ...
      // ]
      this.reports.forEach((report) => this.highlightsFromReport(report, highlights));

      return highlights;
    },

    totalNewVulnerabilities() {
      return this.reports.reduce((counter, current) => {
        return counter + (current.numberOfNewFindings || 0);
      }, 0);
    },

    statusIconName() {
      if (this.totalNewVulnerabilities > 0) {
        return EXTENSION_ICONS.warning;
      }

      if (this.topLevelErrorMessage) {
        return EXTENSION_ICONS.error;
      }

      return EXTENSION_ICONS.success;
    },

    actionButtons() {
      return [
        {
          href: `${this.mr.pipeline.path}/security`,
          text: this.$options.i18n.viewAllPipelineFindings,
          trackFullReportClicked: true,
        },
      ];
    },

    endpoints() {
      // TODO: check if gl.mrWidgetData can be safely removed after we migrate to the
      // widget extension.
      return [
        [this.mr.sastComparisonPathV2, 'SAST'],
        [this.mr.dastComparisonPathV2, 'DAST'],
        [this.mr.secretDetectionComparisonPathV2, 'SECRET_DETECTION'],
        [this.mr.apiFuzzingComparisonPathV2, 'API_FUZZING'],
        [this.mr.coverageFuzzingComparisonPathV2, 'COVERAGE_FUZZING'],
        [this.mr.dependencyScanningComparisonPathV2, 'DEPENDENCY_SCANNING'],
        [this.mr.containerScanningComparisonPathV2, 'CONTAINER_SCANNING'],
      ].filter(([endpoint, reportType]) => {
        const enabledReportsKeyName = convertToCamelCase(reportType.toLowerCase());
        return Boolean(endpoint) && this.mr.enabledReports[enabledReportsKeyName];
      });
    },

    pipelineIid() {
      return this.modalData.vulnerability.found_by_pipeline?.iid;
    },
    branchRef() {
      return this.mr.sourceBranch;
    },

    shouldRenderMrWidget() {
      return !this.mr.isPipelineActive && this.endpoints.length > 0;
    },
  },
  beforeDestroy() {
    this.cleanUpResolveWithAiHandlers();
  },
  methods: {
    handleResolveWithAiSuccess(commentUrl) {
      // the note's id is the hash of the url and also the DOM id which we want to scroll to
      const [, commentNoteId] = commentUrl.split('#');

      const isCommentOnPage = () => document.getElementById(commentNoteId) !== null;
      const closeModalAndScrollToComment = () => {
        this.clearModalData();
        visitUrl(commentUrl);
      };

      if (isCommentOnPage()) {
        closeModalAndScrollToComment();
        return;
      }

      // as a fallback we set a timeout and then manually do a hard page reload
      this.commentNotefallBackTimeout = setTimeout(() => {
        this.cleanUpResolveWithAiHandlers();
        historyPushState(commentUrl);
        window.location.reload();
      }, 3000);

      // observe the DOM and scroll to the comment when it's added
      this.commentMutationObserver = new MutationObserver((mutationList) => {
        for (const mutation of mutationList) {
          // check if the added notes within the mutation contains the comment we're looking for
          if (mutation.addedNodes.length > 0 && isCommentOnPage()) {
            this.cleanUpResolveWithAiHandlers();
            closeModalAndScrollToComment();
            return;
          }
        }
      });

      this.commentMutationObserver.observe(document.getElementById('notes') || document.body, {
        childList: true,
        subtree: true,
      });
    },

    cleanUpResolveWithAiHandlers() {
      if (this.commentNotefallBackTimeout) {
        clearTimeout(this.commentNotefallBackTimeout);
      }
      if (this.commentMutationObserver) {
        this.commentMutationObserver.disconnect();
      }
    },

    updateFindingState(state) {
      this.modalData.vulnerability.state = state;
    },

    handleIsLoading(value) {
      this.isLoading = value;
    },

    fetchCollapsedData() {
      // The backend returns the cached finding objects. Let's remove them as they may cause
      // bugs. Instead, fetch the non-cached data when the finding modal is opened.
      const getFindingWithoutFeedback = (finding) => ({
        ...finding,
        dismissal_feedback: undefined,
        merge_request_feedback: undefined,
        issue_feedback: undefined,
      });

      return this.endpoints.map(([path, reportType]) => () => {
        const props = {
          reportType,
          reportTypeDescription: reportTypes[reportType],
          numberOfNewFindings: 0,
          numberOfFixedFindings: 0,
          added: [],
          fixed: [],
        };

        return axios
          .get(path)
          .then(({ data, headers = {}, status }) => {
            const added = data.added?.map?.(getFindingWithoutFeedback) || [];
            const fixed = data.fixed?.map?.(getFindingWithoutFeedback) || [];

            // If a single report has 25 findings, it means it potentially has more than 25 findings.
            // Therefore, we display the UI hint in the top-level summary.
            // If there are no reports with 25 findings, but the total sum of all reports is still 25 or more,
            // we won't display the UI hint.
            if (added.length === MAX_NEW_VULNERABILITIES) {
              this.hasAtLeastOneReportWithMaxNewVulnerabilities = true;
            }

            const report = {
              ...props,
              ...data,
              added,
              fixed,
              findings: [...added, ...fixed],
              numberOfNewFindings: added.length,
              numberOfFixedFindings: fixed.length,
              testId: this.$options.testId[reportType],
            };

            this.collapsedData = {
              ...this.collapsedData,
              [reportType]: report,
            };

            this.$emit('loaded', added.length);

            return {
              headers,
              status,
              data: report,
            };
          })
          .catch(({ response: { status, headers } }) => {
            const report = { ...props, error: true };

            this.collapsedData = {
              ...this.collapsedData,
              [reportType]: report,
            };

            if (status === 400) {
              this.topLevelErrorMessage = s__(
                'ciReport|Parsing schema failed. Check the validity of your .gitlab-ci.yml content.',
              );
            }

            return { headers, status, data: report };
          });
      });
    },

    highlightsFromReport(report, highlights = { [HIGH]: 0, [CRITICAL]: 0, other: 0 }) {
      // The data we receive from the API is something like:
      // [
      //  { scanner: "SAST", added: [{ id: 15, severity: 'critical' }] },
      //  { scanner: "DAST", added: [{ id: 15, severity: 'high' }] },
      //  ...
      // ]
      return report.added.reduce((acc, vuln) => {
        if (vuln.severity === HIGH) {
          acc[HIGH] += 1;
        } else if (vuln.severity === CRITICAL) {
          acc[CRITICAL] += 1;
        } else {
          acc.other += 1;
        }
        return acc;
      }, highlights);
    },

    statusIconNameReportType(report) {
      if (report.numberOfNewFindings > 0 || report.error) {
        return EXTENSION_ICONS.warning;
      }

      return EXTENSION_ICONS.success;
    },

    statusIconNameVulnerability(vuln) {
      return EXTENSION_ICONS[`severity${capitalizeFirstCharacter(vuln.severity)}`];
    },

    isDismissed(vuln) {
      return vuln.state === 'dismissed';
    },

    setModalData(finding) {
      this.modalData = {
        error: null,
        title: finding.name,
        vulnerability: finding,
      };
    },

    clearModalData() {
      this.modalData = null;
    },

    isAiResolvable(vuln) {
      return vuln.ai_resolution_enabled && this.glAbilities.resolveVulnerabilityWithAi;
    },

    getAiResolvableBadgeId(uuid) {
      return `ai-resolvable-badge-${uuid}`;
    },
  },
  SEVERITY_LEVELS,
  widgetHelpPopover: {
    options: { title: i18n.helpPopoverTitle },
    content: {
      text: i18n.helpPopoverContent,
      learnMorePath: helpPagePath('user/application_security/detect/security_scanning_results', {
        anchor: 'merge-request-security-widget',
      }),
    },
  },
  aiResolutionHelpPopOver: {
    text: s__(
      'ciReport|GitLab Duo Vulnerability Resolution, an AI feature, can suggest a possible fix.',
    ),
    learnMorePath: helpPagePath('user/application_security/vulnerabilities/_index', {
      anchor: 'vulnerability-resolution-in-a-merge-request',
    }),
  },
  testId: {
    SAST: 'sast-scan-report',
    DAST: 'dast-scan-report',
    DEPENDENCY_SCANNING: 'dependency-scan-report',
    SECRET_DETECTION: 'secret-detection-report',
    CONTAINER_SCANNING: 'container-scan-report',
    COVERAGE_FUZZING: 'coverage-fuzzing-report',
    API_FUZZING: 'api-fuzzing-report',
  },
};
</script>

<template>
  <mr-widget
    v-if="shouldRenderMrWidget"
    :error-text="topLevelErrorMessage || $options.i18n.error"
    :has-error="Boolean(topLevelErrorMessage)"
    :fetch-collapsed-data="fetchCollapsedData"
    :status-icon-name="statusIconName"
    :widget-name="$options.name"
    :is-collapsible="isCollapsible"
    :help-popover="$options.widgetHelpPopover"
    :action-buttons="actionButtons"
    :label="$options.i18n.label"
    path="security-reports"
    multi-polling
    data-testid="vulnerability-report-grouped"
    @is-loading="handleIsLoading"
  >
    <template #summary>
      <summary-text
        :total-new-vulnerabilities="totalNewVulnerabilities"
        :is-loading="isLoading"
        :show-at-least-hint="hasAtLeastOneReportWithMaxNewVulnerabilities"
      />
      <summary-highlights
        v-if="!isLoading && totalNewVulnerabilities > 0"
        :highlights="highlights"
      />
    </template>
    <template #content>
      <vulnerability-finding-modal
        v-if="modalData"
        :finding-uuid="modalData.vulnerability.uuid"
        :pipeline-iid="pipelineIid"
        :branch-ref="branchRef"
        :project-full-path="mr.targetProjectFullPath"
        :source-project-full-path="mr.sourceProjectFullPath"
        :show-ai-resolution="true"
        :merge-request-id="mr.id"
        data-testid="vulnerability-finding-modal"
        @hidden="clearModalData"
        @dismissed="updateFindingState('dismissed')"
        @detected="updateFindingState('detected')"
        @resolveWithAiSuccess="handleResolveWithAiSuccess"
      />
      <security-training-promo-widget :security-configuration-path="mr.securityConfigurationPath" />
      <mr-widget-row
        v-for="report in reports"
        :key="report.reportType"
        :widget-name="$options.name"
        :level="2"
        :status-icon-name="statusIconNameReportType(report)"
        :help-popover="helpPopovers[report.reportType]"
        :data-testid="`report-${report.reportType}`"
      >
        <template #header>
          <div>
            <summary-text
              :total-new-vulnerabilities="report.numberOfNewFindings"
              :is-loading="false"
              :error="report.error"
              :scanner="report.reportTypeDescription"
              :data-testid="`${report.testId}`"
              show-at-least-hint
            />
            <summary-highlights
              v-if="report.numberOfNewFindings > 0"
              :highlights="highlightsFromReport(report)"
            />
          </div>
        </template>
        <template #body>
          <div
            v-if="report.numberOfNewFindings || report.numberOfFixedFindings"
            class="gl-mt-2 gl-w-full"
          >
            <dynamic-scroller
              :items="report.findings"
              :min-item-size="32"
              :style="{ maxHeight: '170px' }"
              data-testid="dynamic-content-scroller"
              key-field="uuid"
              class="gl-pr-5"
            >
              <template #default="{ item: vuln, active, index }">
                <dynamic-scroller-item :item="vuln" :active="active">
                  <strong
                    v-if="report.numberOfNewFindings > 0 && index === 0"
                    data-testid="new-findings-title"
                    class="gl-mt-2 gl-block"
                    >{{ $options.i18n.new }}</strong
                  >
                  <strong
                    v-if="report.numberOfFixedFindings > 0 && report.numberOfNewFindings === index"
                    data-testid="fixed-findings-title"
                    class="gl-mt-2 gl-block"
                    >{{ $options.i18n.fixed }}</strong
                  >
                  <mr-widget-row
                    :key="vuln.uuid"
                    :level="3"
                    :widget-name="$options.name"
                    :status-icon-name="statusIconNameVulnerability(vuln)"
                    class="gl-mt-2"
                  >
                    <template #body>
                      {{ $options.SEVERITY_LEVELS[vuln.severity] }}
                      <gl-button
                        variant="link"
                        class="gl-ml-2 gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
                        @click="setModalData(vuln)"
                        >{{ vuln.name }}
                      </gl-button>
                      <gl-badge v-if="isDismissed(vuln)" class="gl-ml-3"
                        >{{ $options.i18n.dismissed }}
                      </gl-badge>
                      <template v-if="isAiResolvable(vuln)">
                        <gl-badge
                          :id="getAiResolvableBadgeId(vuln.uuid)"
                          variant="info"
                          class="gl-ml-3"
                          data-testid="ai-resolvable-badge"
                        >
                          <gl-icon :size="12" name="tanuki-ai" />
                        </gl-badge>
                        <gl-popover
                          trigger="hover focus"
                          placement="top"
                          boundary="viewport"
                          :target="getAiResolvableBadgeId(vuln.uuid)"
                          :data-testid="`ai-resolvable-badge-popover-${vuln.uuid}`"
                        >
                          {{ $options.aiResolutionHelpPopOver.text }}
                          <gl-link :href="$options.aiResolutionHelpPopOver.learnMorePath"
                            >{{ __('Learn more') }}
                          </gl-link>
                        </gl-popover>
                      </template>
                    </template>
                  </mr-widget-row>
                </dynamic-scroller-item>
              </template>
            </dynamic-scroller>
          </div>
        </template>
      </mr-widget-row>
    </template>
  </mr-widget>
</template>
