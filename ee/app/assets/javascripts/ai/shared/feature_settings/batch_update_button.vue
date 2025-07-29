<script>
import { GlButton, GlTooltip } from '@gitlab/ui';

export default {
  name: 'BatchUpdateButton',
  components: {
    GlButton,
    GlTooltip,
  },
  props: {
    tooltipTitle: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>
<template>
  <div ref="batchUpdateButton">
    <gl-button
      :aria-label="__('Apply to all button')"
      category="primary"
      icon="duplicate"
      :disabled="disabled"
      @click="$emit('batch-update')"
    />
    <gl-tooltip
      data-testid="model-batch-assignment-tooltip"
      :target="() => $refs.batchUpdateButton"
      :title="tooltipTitle"
    />
  </div>
</template>
