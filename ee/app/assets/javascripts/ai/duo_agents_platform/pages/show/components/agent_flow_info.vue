<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  components: {
    GlSkeletonLoader,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    status: {
      required: true,
      type: String,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
  },
  computed: {
    payload() {
      return [
        {
          key: 'Status',
          value: this.status,
        },
        {
          key: 'Type',
          value: this.agentFlowDefinition,
        },
      ].map((entry) => {
        return { ...entry, value: entry.value ? entry.value : __('N/A') };
      });
    },
  },
};
</script>
<template>
  <div>
    <ul>
      <li v-for="entry in payload" :key="entry.key" class="gl-mb-4 gl-flex gl-list-none">
        <strong class="gl-pr-3">{{ entry.key }}:</strong>
        <template v-if="isLoading"><gl-skeleton-loader :lines="1" /></template>
        <template v-else>{{ entry.value }}</template>
      </li>
    </ul>
  </div>
</template>
