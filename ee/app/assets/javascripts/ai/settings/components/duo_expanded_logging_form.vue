<script>
import { GlFormCheckbox } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoExpandedLoggingForm',
  i18n: {
    sectionTitle: s__('AiPowered|Enable AI logs'),
    checkboxLabel: s__(
      'AiPowered|Capture detailed information about AI-related activities and requests.',
    ),
  },
  components: {
    GlFormCheckbox,
  },
  inject: ['enabledExpandedLogging'],
  data() {
    return {
      expandedLogging: this.enabledExpandedLogging,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.expandedLogging);
    },
  },
};
</script>
<template>
  <div>
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-checkbox
      v-model="expandedLogging"
      data-testid="ai-logging-checkbox"
      @change="checkboxChanged"
    >
      <span>{{ $options.i18n.checkboxLabel }}</span>
    </gl-form-checkbox>
  </div>
</template>
