<script>
import { GlCollapsibleListbox, GlFormTextarea, GlFormGroup } from '@gitlab/ui';
import { createAlert } from '~/alert';
import DuoWorkflowAction from '../../../components/duo_workflow_action.vue';

export default {
  components: {
    GlCollapsibleListbox,
    GlFormTextarea,
    GlFormGroup,
    DuoWorkflowAction,
  },
  props: {
    defaultAgentFlowType: {
      type: String,
      required: true,
    },
    duoAgentsInvokePath: {
      type: String,
      required: true,
    },
    projectId: {
      type: Number,
      required: true,
    },
    flows: {
      type: Array,
      required: true,
      default: () => [],
    },
  },
  data() {
    return {
      agentflowType: this.defaultAgentFlowType,
      prompt: '',
    };
  },
  computed: {
    selectedAgentFlowText() {
      return this.selectedAgentFlowItem.text;
    },
    selectedAgentFlowItem() {
      return this.flows.find((option) => option.value === this.agentflowType);
    },
    isStartButtonDisabled() {
      return !this.prompt.trim();
    },
  },
  methods: {
    handleAgentFlowStarted(data) {
      this.$emit('agent-flow-started', data);
    },
    handleValidationError() {
      createAlert({
        message: this.selectedAgentFlowItem.validationErrorMessage,
        captureError: false,
        variant: 'danger',
      });
    },
    onAgentFlowSelect(value) {
      this.agentflowType = value;
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group
      :label="s__('DuoAgentsPlatform|Select a flow')"
      label-for="workflow-selector"
      class="gl-mb-5"
    >
      <gl-collapsible-listbox
        id="workflow-selector"
        :items="flows"
        :selected="agentflowType"
        :toggle-text="selectedAgentFlowText"
        @select="onAgentFlowSelect"
      />
    </gl-form-group>

    <gl-form-group
      :label="s__('DuoAgentsPlatform|Prompt')"
      label-for="prompt-textarea"
      class="gl-mb-5"
    >
      <gl-form-textarea
        id="prompt-textarea"
        v-model="prompt"
        :placeholder="selectedAgentFlowItem.helperText"
        :no-resize="false"
        rows="6"
      />
    </gl-form-group>

    <duo-workflow-action
      :agent-privileges="selectedAgentFlowItem.agentPrivileges"
      :project-id="projectId"
      :title="s__('DuoAgentsPlatform|Start agent session')"
      :goal="prompt"
      :workflow-definition="selectedAgentFlowItem.value"
      :duo-workflow-invoke-path="duoAgentsInvokePath"
      :disabled="isStartButtonDisabled"
      :prompt-validator-regex="selectedAgentFlowItem.promptValidatorRegex"
      @agent-flow-started="handleAgentFlowStarted"
      @prompt-validation-error="handleValidationError"
    />
  </div>
</template>
