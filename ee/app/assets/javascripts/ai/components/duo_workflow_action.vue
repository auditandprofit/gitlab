<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';

const FLOW_WEB_ENVIRONMENT = 'web';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
  },
  inject: {
    currentRef: {
      default: null,
      type: String,
    },
  },
  props: {
    projectId: {
      type: Number,
      required: true,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    hoverMessage: {
      type: String,
      required: false,
      default: '',
    },
    goal: {
      type: String,
      required: true,
    },
    workflowDefinition: {
      type: String,
      required: true,
    },
    agentPrivileges: {
      type: Array,
      required: false,
      default: () => [1, 2],
    },
    duoWorkflowInvokePath: {
      type: String,
      required: true,
    },
    promptValidatorRegex: {
      type: RegExp,
      required: false,
      default: null,
    },
    size: {
      type: String,
      default: 'small',
      required: false,
      validator: (size) => ['small', 'medium', 'large'].includes(size),
    },
  },
  methods: {
    startWorkflow() {
      if (this.promptValidatorRegex && !this.promptValidatorRegex.test(this.goal)) {
        this.$emit('prompt-validation-error', this.goal);
        return;
      }
      const requestData = {
        project_id: this.projectId,
        start_workflow: true,
        goal: this.goal,
        environment: FLOW_WEB_ENVIRONMENT,
        workflow_definition: this.workflowDefinition,
        agent_privileges: this.agentPrivileges,
      };

      if (this.currentRef) {
        requestData.source_branch = this.currentRef;
      }

      axios
        .post(this.duoWorkflowInvokePath, requestData)
        .then(({ data }) => {
          this.$emit('agent-flow-started', data);

          createAlert({
            message: __(`Workflow started successfully`),
            captureError: true,
            variant: 'success',
            data,
            renderMessageHTML: true,
          });
        })
        .catch((error) => {
          createAlert({
            message: __('Error occurred when starting the workflow'),
            captureError: true,
            error,
          });
        });
    },
  },
};
</script>
<template>
  <gl-button
    v-gl-tooltip.hover.focus.viewport="{ placement: 'top' }"
    category="primary"
    icon="tanuki-ai"
    :title="hoverMessage"
    :size="size"
    data-testid="duo-workflow-action-button"
    @click="startWorkflow"
  >
    {{ title }}
  </gl-button>
</template>
