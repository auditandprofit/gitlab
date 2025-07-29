<script>
import { s__ } from '~/locale';
import { AGENTFLOW_TYPE_JENKINS_TO_CI } from '../../constants';
import { AGENTS_PLATFORM_SHOW_ROUTE } from '../../router/constants';
import RunAgentFlowForm from '../../components/common/run_agent_flow_form.vue';

export default {
  name: 'DuoAgentPlatformNew',
  components: {
    RunAgentFlowForm,
  },
  inject: ['projectId', 'duoAgentsInvokePath'],
  computed: {
    castProjectId() {
      return Number(this.projectId);
    },
  },
  methods: {
    handleAgentFlowStarted(data) {
      this.$router.push({ name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id: data.id } });
    },
  },
  defaultAgentFlowType: AGENTFLOW_TYPE_JENKINS_TO_CI,
  // These are statics until we have a way to dynamically load them from GraphQL
  flows: [
    {
      value: AGENTFLOW_TYPE_JENKINS_TO_CI,
      text: s__('DuoAgentsPlatform|Convert Jenkins to CI'),
      agentPrivileges: [1, 2, 5],
      promptValidatorRegex: /.*[Jj]enkinsfile.*/,
      helperText: s__('DuoAgentsPlatform|Enter the path to your Jenkinsfile.'),
      validationErrorMessage: s__(
        'DuoAgentsPlatform|Path must be a Jenkinsfile with the exact matching case.',
      ),
    },
  ],
};
</script>
<template>
  <div class="gl-my-10">
    <h1 class="gl-heading-1 gl-mb-0">
      {{ s__('DuoAgentsPlatform|Start an agent session') }}
    </h1>
    <div class="gl-mt-6">
      <run-agent-flow-form
        :default-agent-flow-type="$options.defaultAgentFlowType"
        :duo-agents-invoke-path="duoAgentsInvokePath"
        :project-id="castProjectId"
        :flows="$options.flows"
        @agent-flow-started="handleAgentFlowStarted"
      />
    </div>
  </div>
</template>
