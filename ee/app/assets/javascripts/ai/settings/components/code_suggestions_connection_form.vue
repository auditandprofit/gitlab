<script>
import { GlSprintf, GlFormRadioGroup, GlFormRadio } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'CodeSuggestionsConnectionForm',
  i18n: {
    sectionTitle: s__('AiPowered|Connection method'),
    subtitleText: s__('AiPowered|Specify how code completion requests are sent to the AI gateway.'),
    directConnectionText: s__('AiPowered|Direct connections'),
    directConnectionHelpText: s__(
      'AiPowered|Ideal for lowest latency. An IDE must be able to connect to https://gitlab.com:443.',
    ),
    indirectConnectionText: s__(
      'AiPowered|Indirect connections through GitLab self-managed instance',
    ),
    indirectConnectionHelpText: s__('AiPowered|Might result in requests having higher latency.'),
  },
  components: {
    GlSprintf,
    GlFormRadioGroup,
    GlFormRadio,
  },
  inject: ['disabledDirectConnectionMethod'],
  data() {
    return {
      disabledConnectionMethod: this.disabledDirectConnectionMethod,
    };
  },
  methods: {
    radioChanged(value) {
      this.$emit('change', value);
    },
  },
};
</script>
<template>
  <div>
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-radio-group v-model="disabledConnectionMethod" @change="radioChanged">
      <gl-form-radio :value="false">
        {{ $options.i18n.directConnectionText }}
        <template #help>
          <gl-sprintf :message="$options.i18n.directConnectionHelpText" />
        </template>
      </gl-form-radio>
      <gl-form-radio :value="true">
        {{ $options.i18n.indirectConnectionText }}
        <template #help>
          <gl-sprintf :message="$options.i18n.indirectConnectionHelpText" />
        </template>
      </gl-form-radio>
    </gl-form-radio-group>
  </div>
</template>
