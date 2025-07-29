<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlTab } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import AgentShowPage from '~/clusters/agents/components/show.vue';
import AgentVulnerabilityReport from 'ee/security_dashboard/components/agent/agent_vulnerability_report.vue';
import AgentWorkspacesList from 'ee/workspaces/agent/components/agent_workspaces_list.vue';

export default {
  i18n: {
    securityTabTitle: s__('ClusterAgents|Security'),
    workspacesTabTitle: s__('RemoteDevelopment|Workspaces'),
  },
  components: {
    AgentShowPage,
    GlTab,
    AgentVulnerabilityReport,
    AgentWorkspacesList,
  },
  mixins: [glFeatureFlagMixin()],
  computed: {
    showSecurityTab() {
      return this.glFeatures.kubernetesClusterVulnerabilities;
    },
    showAgentWorkspacesTab() {
      return this.glFeatures.remoteDevelopment;
    },
  },
};
</script>

<template>
  <agent-show-page>
    <template v-if="showSecurityTab" #ee-security-tab="{ clusterAgentId }">
      <gl-tab :title="$options.i18n.securityTabTitle" query-param-value="security">
        <agent-vulnerability-report :cluster-agent-id="clusterAgentId" />
      </gl-tab>
    </template>
    <template v-if="showAgentWorkspacesTab" #ee-workspaces-tab="{ agentName, projectPath }">
      <gl-tab :title="$options.i18n.workspacesTabTitle" query-param-value="workspaces">
        <agent-workspaces-list :agent-name="agentName" :project-path="projectPath" />
      </gl-tab>
    </template>
  </agent-show-page>
</template>
