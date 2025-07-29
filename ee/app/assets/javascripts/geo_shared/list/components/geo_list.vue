<script>
import { GlLoadingIcon } from '@gitlab/ui';
import GeoListEmptyState from './geo_list_empty_state.vue';

export default {
  components: {
    GlLoadingIcon,
    GeoListEmptyState,
  },
  props: {
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasItems: {
      type: Boolean,
      required: false,
      default: false,
    },
    emptyState: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="xl" />
    <template v-else>
      <template v-if="hasItems">
        <slot></slot>
      </template>
      <geo-list-empty-state v-else :empty-state="emptyState" />
    </template>
  </div>
</template>
