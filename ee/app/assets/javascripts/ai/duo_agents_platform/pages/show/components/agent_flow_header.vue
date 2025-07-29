<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { formatAgentFlowName } from '../../../utils';

export default {
  components: {
    GlSkeletonLoader,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
  },
  computed: {
    pageTitle() {
      return formatAgentFlowName(this.agentFlowDefinition, this.$route.params.id);
    },
  },
};
</script>
<template>
  <div class="gl-mt-6">
    <div v-if="isLoading">
      <gl-skeleton-loader :lines="1" :width="400" />
    </div>
    <div v-else>
      <h1 class="gl-heading-1">{{ pageTitle }}</h1>
    </div>
  </div>
</template>
