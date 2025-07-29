<script>
import { GlExperimentBadge } from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import AgentList from '../components/agent_list.vue';
import { ROUTE_NEW_AGENT } from '../constants';

export default {
  name: 'ListAiAgents',
  components: {
    TitleArea,
    AgentList,
    GlExperimentBadge,
  },
  ROUTE_NEW_AGENT,
};
</script>

<template>
  <div>
    <title-area>
      <template #title>
        <div class="gl-flex gl-grow gl-items-center">
          <span>{{ s__('AIAgents|AI Agents') }}</span>
          <gl-experiment-badge />
        </div>
      </template>
      <template #right-actions>
        <router-link
          :to="{ name: $options.ROUTE_NEW_AGENT }"
          class="btn btn-confirm btn-md gl-button"
        >
          {{ s__('AIAgents|Create agent') }}
        </router-link>
      </template>
    </title-area>

    <agent-list />
  </div>
</template>
