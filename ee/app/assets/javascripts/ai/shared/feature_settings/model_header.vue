<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'ModelHeader',
  components: {
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    label: {
      type: String,
      required: true,
    },
  },
  computed: {
    tooltipText() {
      return s__('AdminAIPoweredFeatures|Select the model for the feature');
    },
  },
};
</script>
<template>
  <span>
    {{ label }}
    <gl-icon v-gl-tooltip="tooltipText" variant="info" name="information-o" />
  </span>
</template>
