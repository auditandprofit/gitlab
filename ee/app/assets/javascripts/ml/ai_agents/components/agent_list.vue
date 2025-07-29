<script>
import { GlLoadingIcon, GlTableLite, GlEmptyState } from '@gitlab/ui';
import emptyStateSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-md.svg?url';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { ROUTE_SHOW_AGENT } from '../constants';
import getAiAgents from '../graphql/queries/get_ai_agents.query.graphql';
import eventHub from '../event_hub';

const GRAPHQL_PAGE_SIZE = 30;

export default {
  components: {
    GlLoadingIcon,
    GlEmptyState,
    GlTableLite,
  },
  inject: ['projectPath'],
  data() {
    return {
      emptyStateSvgUrl,
      agents: {},
      errorMessage: undefined,
    };
  },
  i18n: {
    emptyState: {
      title: s__('AiAgents|Create your own AI Agents'),
      description: s__('AiAgents|Create and manage your AI Agents'),
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('AiAgents|Agent Name'),
    },
  ],
  apollo: {
    agents: {
      query: getAiAgents,
      notifyOnNetworkStatusChange: true,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.project?.aiAgents ?? {};
      },
      error(error) {
        this.errorMessage = error.message;
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.agents.loading;
    },
    queryVariables() {
      return {
        fullPath: this.projectPath,
        first: GRAPHQL_PAGE_SIZE,
      };
    },
    ai_agents() {
      return this.agents?.nodes ?? [];
    },
  },
  created() {
    eventHub.$on('agents-changed', () => {
      this.$apollo.queries.agents.refresh();
    });
  },
  ROUTE_SHOW_AGENT,
};
</script>

<template>
  <span>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />
    <gl-table-lite
      v-else-if="ai_agents.length > 0"
      :items="ai_agents"
      sort-by="key"
      sort-direction="asc"
      table-class="gl-text-subtle"
      show-empty
      :fields="$options.fields"
      stacked="false"
      fixed
      data-testId="aiAgentsTable"
    >
      <template #cell(name)="{ item }">
        <router-link
          :to="{ name: $options.ROUTE_SHOW_AGENT, params: { agentId: item.routeId } }"
          data-testid="agent-item"
          class="gl-leading-24 gl-text-default"
        >
          {{ item.name }}
        </router-link>
      </template>
    </gl-table-lite>

    <gl-empty-state
      v-else
      :title="$options.i18n.emptyState.title"
      :svg-path="emptyStateSvgUrl"
      :svg-height="null"
      :description="$options.i18n.emptyState.description"
      class="gl-py-8"
    />
  </span>
</template>
