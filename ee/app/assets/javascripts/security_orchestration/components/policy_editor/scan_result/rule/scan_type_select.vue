<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isCauseOfError } from 'ee/security_orchestration/components/policy_editor/utils';
import { ANY_MERGE_REQUEST, SCAN_FINDING, LICENSE_FINDING } from '../lib';

export default {
  scanTypeOptions: [
    {
      value: ANY_MERGE_REQUEST,
      text: s__('SecurityOrchestration|Any merge request'),
    },
    {
      value: SCAN_FINDING,
      text: s__('SecurityOrchestration|Security Scan'),
    },
    {
      value: LICENSE_FINDING,
      text: s__('SecurityOrchestration|License Scan'),
    },
  ],
  i18n: {
    scanRuleTypeToggleText: s__('SecurityOrchestration|Select scan type'),
  },
  name: 'ScanTypeSelect',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
    index: {
      type: Number,
      required: false,
      default: 0,
    },
    scanType: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    isErrorSource() {
      return isCauseOfError({
        errorSources: this.errorSources,
        primaryKey: 'rules',
        index: this.index,
        location: 'type',
      });
    },
    scanRuleTypeToggleText() {
      return this.scanType ? '' : this.$options.i18n.scanRuleTypeToggleText;
    },
  },
  methods: {
    setScanType(value) {
      this.$emit('select', value);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    id="scanType"
    class="!gl-inline gl-w-auto gl-align-middle"
    :toggle-class="[{ '!gl-shadow-inner-1-red-500': isErrorSource }]"
    :items="$options.scanTypeOptions"
    :selected="scanType"
    :toggle-text="scanRuleTypeToggleText"
    @select="setScanType"
  />
</template>
