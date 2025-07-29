<script>
import AgentFlowHeader from './agent_flow_header.vue';
import AgentFlowInfo from './agent_flow_info.vue';
import AgentFlowLogs from './agent_flow_logs.vue';

export default {
  name: 'AgentFlowDetails',
  components: {
    AgentFlowHeader,
    AgentFlowInfo,
    AgentFlowLogs,
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
    agentFlowCheckpoint: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <div>
    <agent-flow-header :is-loading="isLoading" :agent-flow-definition="agentFlowDefinition" />
    <div class="gl-mt-6 gl-flex">
      <agent-flow-logs :is-loading="isLoading" :agent-flow-checkpoint="agentFlowCheckpoint" />
      <agent-flow-info
        :is-loading="isLoading"
        :status="status"
        :agent-flow-definition="agentFlowDefinition"
      />
    </div>
  </div>
</template>
