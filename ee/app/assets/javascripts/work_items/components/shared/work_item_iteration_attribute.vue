<script>
import { GlIcon } from '@gitlab/ui';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';
import { getIterationPeriod } from 'ee/iterations/utils';

export default {
  components: {
    GlIcon,
    WorkItemAttribute,
  },
  props: {
    iteration: {
      type: Object,
      required: true,
    },
  },
  computed: {
    iterationTitle() {
      return this.iteration?.title;
    },
    iterationCadenceTitle() {
      return this.iteration?.iterationCadence?.title;
    },
    iterationPeriod() {
      return this.iteration && getIterationPeriod(this.iteration);
    },
  },
};
</script>

<template>
  <work-item-attribute
    data-testid="iteration-attribute"
    :title="iterationPeriod"
    title-component-class="gl-mr-3 gl-cursor-help"
    tooltip-placement="top"
  >
    <template #icon>
      <gl-icon name="iteration" :size="12" />
    </template>
    <template #tooltip-text>
      <div data-testid="iteration-title" class="gl-font-bold">
        {{ __('Iteration') }}
      </div>
      <div v-if="iterationCadenceTitle" data-testid="iteration-cadence-text">
        {{ iterationCadenceTitle }}
      </div>
      <div v-if="iterationPeriod" data-testid="iteration-period-text">
        {{ iterationPeriod }}
      </div>
      <div v-if="iterationTitle" data-testid="iteration-title-text">
        {{ iterationTitle }}
      </div>
    </template>
  </work-item-attribute>
</template>
