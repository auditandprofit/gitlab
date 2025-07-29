<script>
import shieldCheckIllustrationUrl from '@gitlab/svgs/dist/illustrations/secure-sm.svg?url';
import magnifyingGlassIllustrationUrl from '@gitlab/svgs/dist/illustrations/search-sm.svg?url';
import pipelineIllustrationUrl from '@gitlab/svgs/dist/illustrations/milestone-sm.svg';
import vulnerabilityIllustrationUrl from '@gitlab/svgs/dist/illustrations/scan-alert-sm.svg';
import { GlButton, GlCard, GlIcon, GlSprintf } from '@gitlab/ui';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { s__, __, n__ } from '~/locale';
import { POLICY_TYPE_COMPONENT_OPTIONS } from '../constants';

const i18n = {
  cancel: __('Cancel'),
  examples: __('Example'),
  selectPolicy: s__('SecurityOrchestration|Select policy'),
  scanResultPolicyTitle: s__('SecurityOrchestration|Merge request approval policy'),
  scanResultPolicyDesc: s__(
    'SecurityOrchestration|Use a merge request approval policy to create rules that %{strongStart}check%{strongEnd} for %{strongStart}security vulnerabilities%{strongEnd} and %{strongStart}license compliance%{strongEnd} before %{strongStart}merging a merge request%{strongEnd}.',
  ),
  scanResultPolicyExample: s__(
    'SecurityOrchestration|If any scanner finds a %{strongStart}newly detected critical vulnerability%{strongEnd} in an open %{strongStart}merge request%{strongEnd} targeting the main branch, then %{strongStart}require two approvals from any two members%{strongEnd} of the application security team.',
  ),
  scanExecutionPolicyTitle: s__('SecurityOrchestration|Scan execution policy'),
  scanExecutionPolicyDesc: s__(
    'SecurityOrchestration|Use a scan execution policy to create rules which %{strongStart}enforce security scans%{strongEnd} for %{strongStart}particular branches%{strongEnd} at %{strongStart}certain times%{strongEnd}. Supported types are SAST, SAST IaC, DAST, Secret detection, Container scanning, and Dependency scanning.',
  ),
  scanExecutionPolicyExample: s__(
    'SecurityOrchestration|%{strongStart}Run a DAST scan%{strongEnd} with Scan Profile A and Site Profile A %{strongStart}when a pipeline runs against the main branch%{strongEnd}.',
  ),
  maximumReachedWarning: s__(
    'SecurityOrchestration|You already have the maximum %{maximumAllowed} %{policyType} %{instance}.',
  ),
  pipelineExecutionPolicyTitle: s__('SecurityOrchestration|Pipeline execution policy'),
  pipelineExecutionPolicyDesc: s__(
    'SecurityOrchestration|Use a pipeline execution policy to %{strongStart}enforce a custom CI/CD configuration%{strongEnd} to run in project pipelines.',
  ),
  pipelineExecutionPolicyExample: s__(
    'SecurityOrchestration|%{strongStart}Run customized GitLab security templates%{strongEnd} across my projects.',
  ),
  vulnerabilityManagementPolicyTitle: s__('SecurityOrchestration|Vulnerability management policy'),
  vulnerabilityManagementPolicyDesc: s__(
    'SecurityOrchestration|Automate %{strongStart}vulnerability management%{strongEnd} workflows.',
  ),
  vulnerabilityManagementPolicyExample: s__(
    'SecurityOrchestration|If any scanner finds a %{strongStart}vulnerability%{strongEnd} that was %{strongStart}previously detected but no longer found%{strongEnd} in a subsequent scan, then automatically %{strongStart}set the status to Resolved%{strongEnd}.',
  ),
};

export default {
  components: {
    GlButton,
    GlCard,
    GlIcon,
    GlSprintf,
  },
  directives: {
    SafeHtml,
  },
  inject: [
    'maxActiveScanExecutionPoliciesReached',
    'maxActiveScanResultPoliciesReached',
    'maxActivePipelineExecutionPoliciesReached',
    'maxActiveVulnerabilityManagementPoliciesReached',
    'maxScanExecutionPoliciesAllowed',
    'maxScanResultPoliciesAllowed',
    'maxPipelineExecutionPoliciesAllowed',
    'maxVulnerabilityManagementPoliciesAllowed',
    'policiesPath',
  ],
  computed: {
    policies() {
      return [
        {
          text: POLICY_TYPE_COMPONENT_OPTIONS.approval.text.toLowerCase(),
          urlParameter: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
          title: i18n.scanResultPolicyTitle,
          description: i18n.scanResultPolicyDesc,
          example: i18n.scanResultPolicyExample,
          imageSrc: shieldCheckIllustrationUrl,
          hasMax: this.maxActiveScanResultPoliciesReached,
          maxPoliciesAllowed: this.maxScanResultPoliciesAllowed,
        },
        {
          text: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text.toLowerCase(),
          urlParameter: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          title: i18n.scanExecutionPolicyTitle,
          description: i18n.scanExecutionPolicyDesc,
          example: i18n.scanExecutionPolicyExample,
          imageSrc: magnifyingGlassIllustrationUrl,
          hasMax: this.maxActiveScanExecutionPoliciesReached,
          maxPoliciesAllowed: this.maxScanExecutionPoliciesAllowed,
        },
        {
          text: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.text.toLowerCase(),
          urlParameter: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
          title: i18n.pipelineExecutionPolicyTitle,
          description: i18n.pipelineExecutionPolicyDesc,
          example: i18n.pipelineExecutionPolicyExample,
          imageSrc: pipelineIllustrationUrl,
          hasMax: this.maxActivePipelineExecutionPoliciesReached,
          maxPoliciesAllowed: this.maxPipelineExecutionPoliciesAllowed,
        },
        {
          text: POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.text.toLowerCase(),
          urlParameter: POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.urlParameter,
          title: i18n.vulnerabilityManagementPolicyTitle,
          description: i18n.vulnerabilityManagementPolicyDesc,
          example: i18n.vulnerabilityManagementPolicyExample,
          imageSrc: vulnerabilityIllustrationUrl,
          hasMax: this.maxActiveVulnerabilityManagementPoliciesReached,
          maxPoliciesAllowed: this.maxVulnerabilityManagementPoliciesAllowed,
        },
      ];
    },
  },
  methods: {
    instanceCountText(policyCount) {
      return n__('policy', 'policies', policyCount);
    },
    constructUrl(policyType) {
      return mergeUrlParams({ type: policyType }, window.location.href);
    },
  },
  i18n,
};
</script>
<template>
  <div class="gl-mb-4">
    <div class="gl-mb-4 gl-grid gl-gap-6 md:gl-grid-cols-2" data-testid="policy-selection-wizard">
      <gl-card
        v-for="option in policies"
        :key="option.title"
        body-class="gl-p-6 gl-flex gl-grow"
        :data-testid="`${option.urlParameter}-card`"
      >
        <div class="gl-mr-6 gl-text-white">
          <img :alt="option.title" aria-hidden="true" :src="option.imageSrc" />
        </div>
        <div class="gl-flex gl-flex-col">
          <div>
            <h4 class="gl-my-0 gl-inline-block">{{ option.title }}</h4>
          </div>
          <div :data-testid="`${option.title}-card`" class="gl-my-5">
            <gl-sprintf :message="option.description">
              <template #strong="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
          </div>
          <h5>{{ $options.i18n.examples }}</h5>
          <div class="gl-my-5">
            <gl-sprintf :message="option.example">
              <template #strong="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
          </div>
          <div :class="{ 'gl-mt-auto': !option.hasMax }">
            <gl-button
              v-if="!option.hasMax"
              variant="confirm"
              :href="constructUrl(option.urlParameter)"
              :data-testid="`select-policy-${option.urlParameter}`"
            >
              {{ $options.i18n.selectPolicy }}
            </gl-button>
            <span
              v-else
              class="gl-text-warning"
              :data-testid="`max-allowed-text-${option.urlParameter}`"
            >
              <gl-icon name="warning" />
              <gl-sprintf :message="$options.i18n.maximumReachedWarning">
                <template #maximumAllowed>{{ option.maxPoliciesAllowed }}</template>
                <template #policyType>{{ option.text }}</template>
                <template #instance>{{ instanceCountText(option.maxPoliciesAllowed) }}</template>
              </gl-sprintf>
            </span>
          </div>
        </div>
      </gl-card>
    </div>
    <gl-button :href="policiesPath" data-testid="back-button">{{ $options.i18n.cancel }}</gl-button>
  </div>
</template>
