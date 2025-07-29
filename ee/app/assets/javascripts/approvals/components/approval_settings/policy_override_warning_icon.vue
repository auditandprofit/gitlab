<script>
import { GlIcon, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__ } from '~/locale';
import { isMergeRequestSettingOverridden } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

export default {
  i18n: {
    title: s__('SecurityOrchestration|Policy override'),
    popoverTextSingle: s__(
      'SecurityOrchestration|Some settings may be affected by policy %{policyName} based on its rules.',
    ),
    popoverTextMultiple: s__(
      'SecurityOrchestration|Some settings may be affected by the following policies based on their rules:',
    ),
  },
  name: 'PolicyOverrideWarningIcon',
  components: {
    GlIcon,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  inject: {
    fullPath: {
      type: String,
    },
    isGroup: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    ...mapState({
      scanResultPolicies: (state) => state.securityOrchestrationModule.scanResultPolicies || [],
    }),
    policiesWithMergeRequestSettingsOverride() {
      return this.scanResultPolicies.filter(
        (policy) =>
          policy.enabled &&
          Object.entries(policy.approval_settings || []).some(([setting, value]) =>
            isMergeRequestSettingOverridden(setting, value),
          ),
      );
    },
    hasApprovalSettingsOverride() {
      return this.policiesWithMergeRequestSettingsOverride.length > 0;
    },
    hasMultiplePolicies() {
      return this.policiesWithMergeRequestSettingsOverride.length > 1;
    },
  },
  created() {
    const { fullPath, isGroup } = this;
    this.fetchScanResultPolicies({ fullPath, isGroup });
  },
  methods: {
    ...mapActions('securityOrchestrationModule', ['fetchScanResultPolicies']),
  },
};
</script>

<template>
  <div v-if="hasApprovalSettingsOverride">
    <gl-popover
      :title="$options.i18n.title"
      target="policy-override-warning-icon"
      show-close-button
    >
      <template v-if="hasMultiplePolicies">
        {{ $options.i18n.popoverTextMultiple }}
        <ul class="gl-pl-5">
          <li v-for="(policy, index) in policiesWithMergeRequestSettingsOverride" :key="index">
            <gl-link :href="policy.editPath" target="_blank" :data-testid="`policy-item-${index}`">
              {{ policy.name }}
            </gl-link>
          </li>
        </ul>
      </template>
      <template v-else>
        <gl-sprintf :message="$options.i18n.popoverTextSingle">
          <template #policyName>
            <gl-link :href="policiesWithMergeRequestSettingsOverride[0].editPath" target="_blank">
              {{ policiesWithMergeRequestSettingsOverride[0].name }}
            </gl-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-popover>

    <gl-icon id="policy-override-warning-icon" name="warning" />
  </div>
</template>
