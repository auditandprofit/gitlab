<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlBadge } from '@gitlab/ui';

export default {
  components: {
    GlBadge,
  },
  props: {
    criteria: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div v-if="criteria.tags.length" class="gl-mt-2 gl-flex gl-flex-wrap gl-gap-2">
    <gl-badge v-for="tag in criteria.tags" :key="tag" variant="info">
      {{ tag }}
    </gl-badge>
  </div>
</template>
