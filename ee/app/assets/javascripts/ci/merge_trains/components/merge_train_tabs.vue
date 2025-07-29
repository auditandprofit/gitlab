<script>
import { GlBadge, GlTab, GlTabs } from '@gitlab/ui';

export default {
  name: 'MergeTrainTabs',
  components: {
    GlBadge,
    GlTab,
    GlTabs,
  },
  props: {
    activeTrain: {
      type: Object,
      required: true,
    },
    mergedTrain: {
      type: Object,
      required: true,
    },
  },
  computed: {
    activeCarCount() {
      return this.activeTrain?.cars?.count || 0;
    },
    mergedCarCount() {
      return this.mergedTrain?.cars?.count || 0;
    },
  },
};
</script>

<template>
  <gl-tabs sync-active-tab-with-query-params lazy @input="$emit('activeTab', $event)">
    <gl-tab query-param-value="active" data-testid="active-cars-tab">
      <template #title>
        <span class="gl-mr-2">{{ s__('Pipelines|Active') }}</span>
        <gl-badge>
          {{ activeCarCount }}
        </gl-badge>
      </template>
      <slot name="active"></slot>
    </gl-tab>
    <gl-tab query-param-value="merged" data-testid="merged-cars-tab">
      <template #title>
        <span class="gl-mr-2">{{ s__('Pipelines|Merged') }}</span>
        <gl-badge>
          {{ mergedCarCount }}
        </gl-badge>
      </template>
      <slot name="merged"></slot>
    </gl-tab>
  </gl-tabs>
</template>
