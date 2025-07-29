<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';

export default {
  components: {
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    statusArray: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <div>
    <gl-icon
      v-for="(status, index) in statusArray"
      :key="index"
      v-gl-tooltip.hover.focus
      :title="status.tooltip"
      :name="status.icon"
      :variant="status.variant"
      class="gl-mx-1 gl-cursor-pointer"
    />
  </div>
</template>
