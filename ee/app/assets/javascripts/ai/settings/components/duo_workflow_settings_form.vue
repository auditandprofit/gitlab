<script>
import { GlFormCheckbox } from '@gitlab/ui';

export default {
  name: 'DuoWorkflowSettingsForm',
  components: {
    GlFormCheckbox,
  },
  props: {
    isMcpEnabled: {
      type: Boolean,
      required: true,
    },
  },
  methods: {
    checkboxChanged(value) {
      this.$emit('change', value);
    },
  },
};
</script>
<template>
  <div>
    <h5>{{ s__('DuoWorkflowSettings|Model Context Protocol') }}</h5>

    <gl-form-checkbox
      :checked="isMcpEnabled"
      data-testid="enable-duo-workflow-mcp-enabled-checkbox"
      name="namespace[ai_settings_attributes][duo_workflow_mcp_enabled]"
      @change="checkboxChanged"
    >
      <span id="enable-duo-workflow-mcp-enabled-checkbox-label">{{
        s__('DuoWorkflowSettings|Turn on Model Context Protocol (MCP) support')
      }}</span>
      <template #help>
        {{
          s__(
            'DuoWorkflowSettings|Turn on MCP support for GitLab Duo Agentic Chat and GitLab Duo Agent Platform',
          )
        }}
      </template>
    </gl-form-checkbox>
  </div>
</template>
