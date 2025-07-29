<script>
import { isEmpty } from 'lodash';
import { GlAlert, GlCollapse, GlTooltipDirective, GlEmptyState, GlButton } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__, n__, sprintf } from '~/locale';
import {
  extractPolicyContent,
  isGroup,
  isProject,
} from 'ee/security_orchestration/components/utils';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import {
  ACTION_SECTION_DISABLE_ERROR,
  ADD_ACTION_LABEL,
  BRANCHES_KEY,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,
  SECURITY_POLICY_ACTIONS,
  PARSING_ERROR_MESSAGE,
  ACTIONS_LABEL,
  ADD_RULE_LABEL,
  RULES_LABEL,
  RULE_SECTION_DISABLE_ERROR,
  MAX_ALLOWED_RULES_LENGTH,
  MAX_ALLOWED_APPROVER_ACTION_LENGTH,
  SETTING_SECTION_DISABLE_ERROR,
} from '../constants';
import DisabledSection from '../disabled_section.vue';
import EditorLayout from '../editor_layout.vue';
import ScanFilterSelector from '../scan_filter_selector.vue';
import SettingsSection from './settings/settings_section.vue';
import ActionSection from './action/action_section.vue';
import BotCommentAction from './action/bot_message_action.vue';
import RuleSection from './rule/rule_section.vue';
import FallbackAndEdgeCasesSection from './advanced_settings/fallback_and_edge_cases_section.vue';
import PolicyExceptions from './advanced_settings/policy_exceptions/policy_exceptions.vue';
import {
  ACTION_LISTBOX_ITEMS,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  buildAction,
  buildSettingsList,
  createPolicyObject,
  getInvalidBranches,
  getPolicyYaml,
  emptyBuildRule,
  humanizeInvalidBranchesError,
  BOT_MESSAGE_TYPE,
  PERMITTED_INVALID_SETTINGS_KEY,
  REQUIRE_APPROVAL_TYPE,
  WARN_TYPE,
} from './lib';

export default {
  ACTION_LISTBOX_ITEMS: ACTION_LISTBOX_ITEMS(),
  ADD_RULE_LABEL,
  RULES_LABEL,
  SECURITY_POLICY_ACTIONS,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,
  i18n: {
    ACTION_SECTION_DISABLE_ERROR,
    ADD_ACTION_LABEL,
    PARSING_ERROR_MESSAGE,
    RULE_SECTION_DISABLE_ERROR,
    SETTING_SECTION_DISABLE_ERROR,
    accordionTitle: __('Advanced'),
    filterHeaderText: s__('SecurityOrchestration|Choose an action'),
    notOwnerButtonText: __('Learn more'),
    notOwnerDescription: s__(
      'SecurityOrchestration|Merge request approval policies can only be created by project owners.',
    ),
    settingsTitle: s__('ScanResultPolicy|Override project approval settings'),
    yamlPreview: s__('SecurityOrchestration|.yaml preview'),
    ACTIONS_LABEL,
    settingWarningTitle: s__(
      'SecurityOrchestration|Only overriding settings and bot message will take effect',
    ),
    settingWarningDescription: s__(
      "SecurityOrchestration|For any MR that matches this policy's rules, only the override project approval settings apply and bot message enabled. No additional approvals are required.",
    ),
    settingErrorTitle: s__('SecurityOrchestration|Cannot create an empty policy'),
    settingErrorDescription: s__(
      "SecurityOrchestration|This policy doesn't contain any actions or override project approval settings. You cannot create an empty policy.",
    ),
    approverActionTooltip: s__(
      'SecurityOrchestration|Merge request approval policies allow a maximum of 5 approver actions.',
    ),
    botActionTooltip: s__(
      'SecurityOrchestration|Merge request approval policies allow a maximum 1 bot message action.',
    ),
    exceedingRulesMessage: s__(
      'SecurityOrchestration|You can add a maximum of %{rulesCount} %{rules}.',
    ),
  },
  components: {
    ActionSection,
    BotCommentAction,
    DisabledSection,
    FallbackAndEdgeCasesSection,
    GlAlert,
    GlButton,
    GlCollapse,
    GlEmptyState,
    EditorLayout,
    PolicyExceptions,
    RuleSection,
    ScanFilterSelector,
    SettingsSection,
  },
  directives: { GlTooltip: GlTooltipDirective },
  apollo: {
    linkedSppGroups: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return { fullPath: this.namespacePath };
      },
      update(data) {
        return data?.project?.securityPolicyProjectLinkedGroups?.nodes || [];
      },
      result({ data }) {
        const groups = data?.project?.securityPolicyProjectLinkedGroups?.nodes || [];
        const currentSettingsValue =
          this.policy.approval_settings?.[BLOCK_GROUP_BRANCH_MODIFICATION];
        if (groups.length && currentSettingsValue === undefined) {
          const newSettings = {
            ...(this.policy.approval_settings || {}),
            [BLOCK_GROUP_BRANCH_MODIFICATION]: true,
          };
          this.updateSettings(newSettings);
        }
      },
      skip() {
        return isGroup(this.namespaceType);
      },
    },
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'disableScanPolicyUpdate',
    'namespaceId',
    'namespacePath',
    'namespaceType',
    'policyEditorEmptyStateSvgPath',
    'scanPolicyDocumentationPath',
  ],
  props: {
    errorSources: {
      type: Array,
      required: true,
    },
    existingPolicy: {
      type: Object,
      required: false,
      default: null,
    },
    isCreating: {
      type: Boolean,
      required: true,
    },
    isDeleting: {
      type: Boolean,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    selectedPolicyType: {
      type: String,
      required: true,
    },
  },
  data() {
    const newPolicyYaml = getPolicyYaml({
      isGroup: isGroup(this.namespaceType),
    });

    const yamlEditorValue = this.existingPolicy
      ? policyToYaml(this.existingPolicy, this.selectedPolicyType)
      : newPolicyYaml;

    const { policy, parsingError } = createPolicyObject(yamlEditorValue);

    return {
      errors: { action: [] },
      isExpanded: false,
      invalidBranches: [],
      linkedSppGroups: [],
      parsingError,
      policy,
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'scan-result-policy-editor',
      ),
      mode: EDITOR_MODE_RULE,
      yamlEditorValue,
    };
  },
  computed: {
    actionError() {
      const actionErrors = this.errorSources.filter(([primaryKey]) => primaryKey === 'action');
      if (actionErrors.length) {
        // Refactor action error messages to be consistent with the other `errorSources`
        // as part of https://gitlab.com/gitlab-org/gitlab/-/issues/486021
        return { action: actionErrors[0][3] };
      }

      return this.errors;
    },
    actions() {
      const actions = this.policy?.actions || [];
      const hasBotAction = actions.some(({ type }) => type === BOT_MESSAGE_TYPE);
      // If the yaml does not have a bot message action, then the bot message will be created as if
      // the bot message action exists and is enabled. Thus, we add it into the actions for rule
      // mode so the user can remove it
      if (hasBotAction) {
        return actions;
      }

      return [...actions, buildAction(BOT_MESSAGE_TYPE)];
    },
    approversActions() {
      return this.actions
        .filter(({ type }) => type === REQUIRE_APPROVAL_TYPE)
        .slice(0, MAX_ALLOWED_APPROVER_ACTION_LENGTH);
    },
    botActions() {
      const botActions = this.actions.filter(({ type }) => type === BOT_MESSAGE_TYPE);
      return botActions.filter(({ enabled }) => enabled);
    },
    hasWarnAction() {
      return (
        this.glFeatures.securityPolicyApprovalWarnMode &&
        this.botActions.length === 1 &&
        this.approversActions.length === 1 &&
        this.approversActions[0].approvals_required === 0
      );
    },
    hasNewSplitView() {
      return this.glFeatures.securityPoliciesSplitView;
    },
    icon() {
      return this.isExpanded ? 'chevron-down' : 'chevron-right';
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    settings() {
      return buildSettingsList({
        settings: this.policy.approval_settings,
        options: {
          hasLinkedGroups: Boolean(this.linkedSppGroups.length),
          namespaceType: this.namespaceType,
        },
      });
    },
    isWithinLimit() {
      return this.policy.rules?.length < MAX_ALLOWED_RULES_LENGTH;
    },
    addRuleTitle() {
      const rules = n__('rule', 'rules', this.policy.rules?.length);
      return sprintf(this.$options.i18n.exceedingRulesMessage, {
        rulesCount: MAX_ALLOWED_RULES_LENGTH,
        rules,
      });
    },
    hasRequireApprovalAction() {
      return this.policy.actions?.some(({ type }) => type === REQUIRE_APPROVAL_TYPE);
    },
    showAlert() {
      return isEmpty(this.parsingError) && !this.hasRequireApprovalAction;
    },
    hasEmptyActions() {
      return this.policy.actions?.every(
        ({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled,
      );
    },
    hasEmptyRules() {
      return this.policy.rules?.length === 0 || this.policy.rules?.at(0)?.type === '';
    },
    hasEmptySettings() {
      return (
        isEmpty(this.policy.approval_settings) ||
        Object.entries(this.policy.approval_settings).every(([key, value]) => {
          if (key === PERMITTED_INVALID_SETTINGS_KEY) {
            return true;
          }

          if (key === BLOCK_GROUP_BRANCH_MODIFICATION && typeof value !== 'boolean') {
            return !value.enabled;
          }

          return !value;
        })
      );
    },
    hasDisabledBotMessageAction() {
      return this.policy.actions?.some(
        ({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled,
      );
    },
    isRuleMode() {
      return this.mode === EDITOR_MODE_RULE;
    },
    allBranches() {
      return this.policy.rules.flatMap((rule) => rule.branches);
    },
    rulesHaveBranches() {
      return this.policy.rules.some(this.ruleHasBranchesProperty);
    },
    settingAlert() {
      if ((this.hasEmptySettings && this.hasEmptyActions) || this.hasEmptyRules) {
        return {
          variant: 'danger',
          title: this.$options.i18n.settingErrorTitle,
          description: this.$options.i18n.settingErrorDescription,
        };
      }

      return {
        variant: 'warning',
        title: this.$options.i18n.settingWarningTitle,
        description: this.$options.i18n.settingWarningDescription,
      };
    },
  },
  watch: {
    invalidBranches(branches) {
      if (branches.length > 0) {
        this.$emit('error', humanizeInvalidBranchesError([...branches]));
      } else {
        this.$emit('error', '');
      }
    },
  },
  methods: {
    areManifestsEqual(manifest) {
      const policyManifest = policyToYaml(this.policy, this.selectedPolicyType);
      return policyManifest === manifest && this.hasNewSplitView;
    },
    ruleHasBranchesProperty(rule) {
      return BRANCHES_KEY in rule;
    },
    addAction(type) {
      if (!this.policy.actions) {
        this.policy = { ...this.policy, actions: [] };
      }

      if (
        (this.hasWarnAction && type !== WARN_TYPE) ||
        (!this.hasWarnAction && type === WARN_TYPE)
      ) {
        this.policy.actions = [];
      }

      switch (type) {
        case WARN_TYPE:
          this.addWarnAction();
          break;
        case REQUIRE_APPROVAL_TYPE:
          this.addApproverAction();
          break;
        case BOT_MESSAGE_TYPE:
        default:
          this.addBotAction();
          break;
      }

      this.updateYamlEditorValue(this.policy);
    },
    addApproverAction() {
      const lastApproverActionIndex = this.policy.actions.findLastIndex(
        ({ type }) => type === REQUIRE_APPROVAL_TYPE,
      );
      const nextIndex = lastApproverActionIndex + 1;
      this.policy.actions.splice(nextIndex, 0, buildAction(REQUIRE_APPROVAL_TYPE));
    },
    addBotAction() {
      const action = buildAction(BOT_MESSAGE_TYPE);

      if (this.hasDisabledBotMessageAction) {
        this.updateBotAction(action);
      } else {
        this.policy.actions.push(action);
      }
    },
    addWarnAction() {
      this.policy.actions = buildAction(WARN_TYPE);
    },
    removeApproverAction(index) {
      this.policy.actions?.splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    removeWarnAction() {
      this.policy.actions = [];
      this.updateYamlEditorValue(this.policy);
    },
    updateAction(values, index) {
      this.policy.actions.splice(index, 1, values);
      this.errors.action = [];
      this.updateYamlEditorValue(this.policy);
    },
    updateBotAction(values) {
      const actions = this.policy.actions || [];
      const indexOfActionToUpdate = actions.findIndex((a) => a.type === BOT_MESSAGE_TYPE);

      actions.splice(indexOfActionToUpdate, 1, values);
      this.errors.action = [];
      this.updateYamlEditorValue(this.policy);
    },
    updateFallbackAndEdgeCases(property, value) {
      this.parsingError.fallback = false;
      this.handleUpdateProperty(property, value);
    },
    updateSettings(values) {
      if (!this.policy.approval_settings) {
        this.policy = {
          ...this.policy,
          approval_settings: values,
        };
      } else {
        this.policy.approval_settings = values;
      }

      this.updateYamlEditorValue(this.policy);
    },
    addRule() {
      this.policy.rules.push(emptyBuildRule());
      this.updateYamlEditorValue(this.policy);
    },
    removeRule(index) {
      this.policy.rules.splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateRule(ruleIndex, rule) {
      this.policy.rules.splice(ruleIndex, 1, rule);
      this.updateSettings(this.settings);
      this.updateYamlEditorValue(this.policy);
    },
    handleParsingError() {
      this.parsingError = { ...this.parsingError, actions: true };
    },
    async handleModifyPolicy(action) {
      /**
       * backend only accepts the old format
       * policy body is extracted
       * and policy type is added to a policy body
       */
      const policy = extractPolicyContent({
        manifest: this.yamlEditorValue,
        type: this.selectedPolicyType,
        withType: true,
      });

      this.$emit('save', {
        action,
        policy: policyBodyToYaml(policy),
        isRuleMode: this.isRuleMode,
      });
    },
    handleRemoveProperty(property) {
      const { [property]: removedProperty, ...updatedPolicy } = this.policy;
      this.policy = updatedPolicy;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    updateYaml(manifest) {
      if (this.areManifestsEqual(manifest)) {
        return;
      }

      const { policy, parsingError } = createPolicyObject(manifest);
      this.yamlEditorValue = manifest;
      this.parsingError = parsingError;
      this.policy = policy;
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = policyToYaml(policy, this.selectedPolicyType);
    },
    async changeEditorMode(mode) {
      this.mode = mode;
      if (this.isRuleMode) {
        if (!this.hasEmptyRules && this.isProject && this.rulesHaveBranches) {
          this.invalidBranches = await getInvalidBranches({
            branches: this.allBranches,
            projectId: this.namespaceId,
          });
        }
      }
    },
    shouldDisableActionSelector(filter) {
      if (filter === WARN_TYPE) {
        return this.hasWarnAction;
      }

      if (filter === BOT_MESSAGE_TYPE) {
        return !this.hasWarnAction && this.botActions.length > 0;
      }

      return (
        !this.hasWarnAction && this.approversActions.length >= MAX_ALLOWED_APPROVER_ACTION_LENGTH
      );
    },
    toggleCollapse() {
      this.isExpanded = !this.isExpanded;
    },
    customFilterSelectorTooltip(filter) {
      if (filter.value === BOT_MESSAGE_TYPE) {
        return this.$options.i18n.botActionTooltip;
      }

      return this.$options.i18n.approverActionTooltip;
    },
  },
};
</script>

<template>
  <editor-layout
    v-if="!disableScanPolicyUpdate"
    :is-editing="isEditing"
    :is-removing-policy="isDeleting"
    :is-updating-policy="isCreating"
    :policy="policy"
    :yaml-editor-value="yamlEditorValue"
    @remove-policy="handleModifyPolicy($options.SECURITY_POLICY_ACTIONS.REMOVE)"
    @save-policy="handleModifyPolicy"
    @remove-property="handleRemoveProperty"
    @update-property="handleUpdateProperty"
    @update-yaml="updateYaml"
    @update-editor-mode="changeEditorMode"
  >
    <template #rules>
      <disabled-section
        :disabled="parsingError.rules"
        :error="$options.i18n.RULE_SECTION_DISABLE_ERROR"
        data-testid="disabled-rules"
      >
        <template #title>
          <h4>{{ $options.RULES_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-rounded-base gl-bg-subtle gl-p-6"></div>
        </template>

        <rule-section
          v-for="(rule, index) in policy.rules"
          :key="rule.id"
          :data-testid="`rule-${index}`"
          class="gl-mb-4"
          :error-sources="errorSources"
          :index="index"
          :init-rule="rule"
          @changed="updateRule(index, $event)"
          @remove="removeRule(index)"
        />

        <div class="security-policies-bg-subtle gl-mb-5 gl-rounded-base gl-p-5">
          <span
            v-gl-tooltip="{
              disabled: isWithinLimit,
              title: addRuleTitle,
            }"
            data-testid="add-rule-wrapper"
          >
            <gl-button
              variant="link"
              data-testid="add-rule"
              :disabled="!isWithinLimit"
              @click="addRule"
            >
              {{ $options.ADD_RULE_LABEL }}
            </gl-button>
          </span>
        </div>
      </disabled-section>
    </template>
    <template #actions>
      <disabled-section
        :disabled="parsingError.actions"
        :error="$options.i18n.ACTION_SECTION_DISABLE_ERROR"
        data-testid="disabled-actions"
      >
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-rounded-base gl-bg-subtle gl-p-6"></div>
        </template>

        <div v-if="!hasWarnAction">
          <action-section
            v-for="(action, index) in approversActions"
            :key="action.id"
            :data-testid="`action-${index}`"
            class="gl-mb-4"
            :action-index="index"
            :init-action="action"
            :errors="actionError.action"
            @error="handleParsingError"
            @changed="updateAction($event, index)"
            @remove="removeApproverAction(index)"
          />

          <bot-comment-action
            v-for="action in botActions"
            :key="action.id"
            class="gl-mb-4"
            :init-action="action"
            @changed="updateBotAction($event)"
          />
        </div>

        <div v-else>
          <action-section
            v-for="(action, index) in approversActions"
            :key="action.id"
            :data-testid="`warn-action`"
            class="gl-mb-4"
            :action-index="index"
            :init-action="action"
            :is-warn-type="true"
            :errors="actionError.action"
            @error="handleParsingError"
            @changed="updateAction($event, index)"
            @remove="removeWarnAction"
          />
        </div>

        <scan-filter-selector
          class="gl-w-full"
          :button-text="$options.i18n.ADD_ACTION_LABEL"
          :header="$options.i18n.filterHeaderText"
          :custom-filter-tooltip="customFilterSelectorTooltip"
          :should-disable-filter="shouldDisableActionSelector"
          :filters="$options.ACTION_LISTBOX_ITEMS"
          @select="addAction"
        />
      </disabled-section>
    </template>
    <template #settings>
      <gl-button
        class="gl-mt-5"
        variant="link"
        :icon="icon"
        data-testid="collapse-button"
        @click="toggleCollapse"
      >
        <h4 class="gl-mr-3">{{ $options.i18n.accordionTitle }}</h4>
      </gl-button>
      <gl-collapse v-model="isExpanded" class="gl-ml-7 gl-mt-0">
        <disabled-section
          :disabled="parsingError.settings"
          :error="$options.i18n.SETTING_SECTION_DISABLE_ERROR"
          data-testid="disabled-settings"
        >
          <template #title>
            <h4>{{ $options.i18n.settingsTitle }}</h4>
          </template>

          <settings-section :rules="policy.rules" :settings="settings" @changed="updateSettings" />
        </disabled-section>

        <policy-exceptions :exceptions="policy.bypass_settings" @changed="handleUpdateProperty" />

        <fallback-and-edge-cases-section
          :has-error="parsingError.fallback"
          :policy="policy"
          @changed="updateFallbackAndEdgeCases"
        />
      </gl-collapse>
      <gl-alert
        v-if="showAlert"
        data-testid="empty-actions-alert"
        class="gl-mb-5"
        :title="settingAlert.title"
        :variant="settingAlert.variant"
        :dismissible="false"
      >
        {{ settingAlert.description }}
      </gl-alert>
    </template>
  </editor-layout>
  <gl-empty-state
    v-else
    :description="$options.i18n.notOwnerDescription"
    :primary-button-link="documentationPath"
    :primary-button-text="$options.i18n.notOwnerButtonText"
    :svg-path="policyEditorEmptyStateSvgPath"
    :svg-height="null"
    title=""
  />
</template>
