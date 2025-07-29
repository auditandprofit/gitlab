<script>
import { GlIcon, GlFormCheckbox, GlPopover } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { UNBLOCK_RULES_KEY, UNBLOCK_RULES_TEXT } from './constants';

export default {
  i18n: {
    UNBLOCK_RULES_TEXT,
    popoverTitle: __('Information'),
    popoverDesc: s__(
      'ScanResultPolicy|When enabled, approval rules do not block merge requests when a scan is required by a scan execution policy or a pipeline execution policy but a required scan artifact is missing from the target branch. This option only works when the project or group has an existing scan execution policy or pipeline execution policy with matching scanners.',
    ),
  },
  components: {
    GlIcon,
    GlFormCheckbox,
    GlPopover,
  },
  props: {
    policyTuning: {
      type: Object,
      required: false,
      default: () => ({ unblock_rules_using_execution_policies: false }),
    },
  },
  methods: {
    updateSetting(key, value) {
      const updates = { [key]: value };
      this.updatePolicy(updates);
    },
    updatePolicy(updates = {}) {
      this.$emit('changed', 'policy_tuning', { ...this.policyTuning, ...updates });
    },
  },
  UNBLOCK_RULES_KEY,
  POPOVER_TARGET_SELECTOR: 'comparison-tuning-popover',
};
</script>

<template>
  <div class="gl-mt-3">
    <gl-form-checkbox
      :id="$options.UNBLOCK_RULES_KEY"
      class="gl-inline-block"
      :checked="policyTuning[$options.UNBLOCK_RULES_KEY]"
      @change="updateSetting($options.UNBLOCK_RULES_KEY, $event)"
    >
      {{ $options.i18n.UNBLOCK_RULES_TEXT }}
      <gl-icon :id="$options.POPOVER_TARGET_SELECTOR" name="information-o" />
    </gl-form-checkbox>

    <gl-popover :target="$options.POPOVER_TARGET_SELECTOR" :title="$options.i18n.popoverTitle">
      {{ $options.i18n.popoverDesc }}
    </gl-popover>
  </div>
</template>
