<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { parseAllowDenyLicenseList } from 'ee/security_orchestration/components/policy_editor/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { BOT_MESSAGE_TYPE, REQUIRE_APPROVAL_TYPE } from '../../policy_editor/scan_result/lib';
import { SUMMARY_TITLE } from '../constants';
import InfoRow from '../info_row.vue';
import DrawerLayout from '../drawer_layout.vue';
import ToggleList from '../toggle_list.vue';
import DenyAllowViewList from './deny_allow_view_list.vue';
import Approvals from './policy_approvals.vue';
import EdgeCaseSettings from './edge_case_settings.vue';
import Settings from './policy_settings.vue';
import { humanizeRules, mapApproversToArray } from './utils';

export default {
  i18n: {
    botActionText: s__('SecurityOrchestration|Send a bot message when the conditions match.'),
    approvalsSubheader: s__('SecurityOrchestration|If any of the following occur:'),
    fallbackTitle: s__('SecurityOrchestration|Fallback behavior in case of policy failure'),
    summary: SUMMARY_TITLE,
    scanResult: s__('SecurityOrchestration|Merge request approval'),
  },
  components: {
    DenyAllowViewList,
    GlSprintf,
    ToggleList,
    DrawerLayout,
    InfoRow,
    Approvals,
    EdgeCaseSettings,
    Settings,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
    showPolicyScope: {
      type: Boolean,
      required: false,
      default: true,
    },
    showStatus: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    actions() {
      return this.parsedYaml?.actions;
    },
    description() {
      return this.parsedYaml?.description || '';
    },
    fallbackBehaviorText() {
      switch (this.parsedYaml?.fallback_behavior?.fail) {
        case 'open':
          return s__(
            'ScanResultPolicy|Fail open: Allow the merge request to proceed, even if not all criteria are met',
          );
        case 'closed':
          return s__(
            'ScanResultPolicy|Fail closed: Block the merge request until all criteria are met',
          );
        default:
          return null;
      }
    },
    humanizedRules() {
      return humanizeRules(this.parsedYaml?.rules);
    },
    parsedYaml() {
      return fromYaml({
        manifest: this.policy.yaml,
        type: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
      });
    },
    hasRequireApprovals() {
      return this.requireApprovals.length > 0;
    },
    isWarnMode() {
      return (
        this.requireApprovals.some((action) => action.approvals_required === 0) &&
        this.hasBotMessage
      );
    },
    requireApprovals() {
      return this.actions?.filter((action) => action.type === REQUIRE_APPROVAL_TYPE) || [];
    },
    policyScope() {
      return this.policy?.policyScope;
    },
    actionApprovers() {
      return this.policy?.actionApprovers || [];
    },
    edgeCaseSettings() {
      return this.parsedYaml?.policy_tuning || {};
    },
    hasEdgeCaseSettings() {
      return Object.values(this.edgeCaseSettings).some((v) => v);
    },
    settings() {
      return this.parsedYaml?.approval_settings || {};
    },
    hasBotMessage() {
      return !this.actions?.some(({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled);
    },
    shouldRenderBotMessage() {
      return this.hasBotMessage && !this.isWarnMode;
    },
  },
  methods: {
    capitalizedCriteriaMessage(message) {
      return capitalizeFirstCharacter(message.trim());
    },
    showItems(items) {
      return items?.length > 0;
    },
    mapApproversToArray(index) {
      return mapApproversToArray(this.actionApprovers[index]);
    },
    getDenyAllowList(licenses) {
      return parseAllowDenyLicenseList({ licenses });
    },
    showDenyAllowList(licenses = {}) {
      return this.getDenyAllowList(licenses).licenses.length > 0;
    },
  },
};
</script>

<template>
  <drawer-layout
    key="scan_result_policy"
    :description="description"
    :policy="policy"
    :policy-scope="policyScope"
    :type="$options.i18n.scanResult"
    :show-policy-scope="showPolicyScope"
    :show-status="showStatus"
  >
    <template v-if="parsedYaml" #summary>
      <info-row data-testid="policy-summary" :label="$options.i18n.summary">
        <approvals
          v-for="(action, index) in requireApprovals"
          :key="action.id"
          class="gl-mb-2 gl-block"
          :action="action"
          :approvers="mapApproversToArray(index)"
          :is-last-item="!hasBotMessage"
          :is-warn-mode="isWarnMode"
        />

        <div v-if="shouldRenderBotMessage" class="gl-mt-2" data-testid="policy-bot-message">
          {{ $options.i18n.botActionText }}
        </div>

        <p
          v-if="hasRequireApprovals"
          data-testid="approvals-subheader"
          class="gl-mb-0 gl-mt-6 gl-block"
        >
          {{ $options.i18n.approvalsSubheader }}
        </p>

        <div
          v-for="(
            { summary, branchExceptions, licenses, criteriaMessage, criteriaList, denyAllowList },
            idx
          ) in humanizedRules"
          :key="idx"
          class="gl-pt-5"
        >
          <gl-sprintf :message="summary">
            <template #licenses>
              <toggle-list v-if="showItems(licenses)" class="gl-mb-2" :items="licenses" />
            </template>
          </gl-sprintf>
          <deny-allow-view-list
            v-if="showDenyAllowList(denyAllowList)"
            class="gl-my-4"
            :is-denied="getDenyAllowList(denyAllowList).isDenied"
            :items="getDenyAllowList(denyAllowList).licenses"
          />
          <toggle-list
            v-if="showItems(branchExceptions)"
            class="gl-mb-2"
            :items="branchExceptions"
          />
          <p v-if="criteriaMessage" class="gl-mb-3">
            {{ capitalizedCriteriaMessage(criteriaMessage) }}
          </p>
          <ul class="gl-m-0">
            <li v-for="(criteria, criteriaIdx) in criteriaList" :key="criteriaIdx" class="gl-mt-2">
              {{ criteria }}
            </li>
          </ul>
          <settings :settings="settings" />
        </div>
      </info-row>
    </template>

    <template #additional-details>
      <info-row
        v-show="fallbackBehaviorText"
        :label="$options.i18n.fallbackTitle"
        data-testid="fallback-details"
      >
        {{ fallbackBehaviorText }}
      </info-row>
      <edge-case-settings v-if="hasEdgeCaseSettings" :settings="edgeCaseSettings" />
      <slot name="additional-details"></slot>
    </template>
  </drawer-layout>
</template>
