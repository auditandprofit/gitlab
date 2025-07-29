<script>
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import AgentFlowList from '../../components/common/agent_flow_list.vue';
import { getAgentFlows } from '../../graphql/queries/get_agent_flows.query.graphql';
import { AGENTS_PLATFORM_NEW_ROUTE } from '../../router/constants';
import { AGENT_PLATFORM_INDEX_COMPONENT_NAME } from '../../constants';

export default {
  name: AGENT_PLATFORM_INDEX_COMPONENT_NAME,
  components: {
    GlButton,
    GlLoadingIcon,
    AgentFlowList,
  },
  inject: ['emptyStateIllustrationPath', 'projectPath'],
  data() {
    return {
      workflows: [],
      workflowsPageInfo: {},
    };
  },
  apollo: {
    workflows: {
      query: getAgentFlows,
      variables() {
        return {
          projectPath: this.projectPath,
          first: 20,
          before: null,
          last: null,
        };
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
      },
      result({ data }) {
        this.workflowsPageInfo = data?.duoWorkflowWorkflows?.pageInfo || {};
      },
      error(error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to fetch workflows'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoadingWorkflows() {
      return this.$apollo.queries.workflows.loading;
    },
  },
  methods: {
    handleNextPage() {
      this.$apollo.queries.workflows.refetch({
        projectPath: this.projectPath,
        before: null,
        after: this.workflowsPageInfo.endCursor,
        first: 20,
        last: null,
      });
    },
    handlePrevPage() {
      this.$apollo.queries.workflows.refetch({
        projectPath: this.projectPath,
        after: null,
        before: this.workflowsPageInfo.startCursor,
        first: null,
        last: 20,
      });
    },
  },
  newPage: AGENTS_PLATFORM_NEW_ROUTE,
};
</script>
<template>
  <div class="gl-mt-3 gl-flex gl-flex-col">
    <div class="gl-flex gl-justify-end">
      <gl-button
        variant="confirm"
        :to="{ name: $options.newPage }"
        data-testid="new-agent-flow-button"
        >{{ s__('DuoAgentsPlatform|New session') }}</gl-button
      >
    </div>
    <gl-loading-icon v-if="isLoadingWorkflows" size="lg" />
    <agent-flow-list
      v-else
      class="gl-mt-5"
      :empty-state-illustration-path="emptyStateIllustrationPath"
      :workflows="workflows"
      :workflows-page-info="workflowsPageInfo"
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
  </div>
</template>
