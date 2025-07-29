<script>
import { GlExperimentBadge, GlLoadingIcon, GlEmptyState, GlAlert } from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import getLatestAiAgentVersion from '../graphql/queries/get_latest_ai_agent_version.query.graphql';
import AgentForm from '../components/agent_form.vue';
import DeleteAgent from '../components/agent_delete.vue';
import updateAiAgent from '../graphql/mutations/update_ai_agent.mutation.graphql';
import destroyAiAgent from '../graphql/mutations/destroy_ai_agent.mutation.graphql';
import { I18N_EDIT_AGENT } from '../constants';
import eventHub from '../event_hub';

export default {
  name: 'EditAiAgent',
  components: {
    TitleArea,
    GlExperimentBadge,
    GlLoadingIcon,
    AgentForm,
    GlEmptyState,
    GlAlert,
    DeleteAgent,
  },
  I18N_EDIT_AGENT,
  inject: ['projectPath'],
  data() {
    return {
      errorMessage: '',
      loading: false,
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    latestAgentVersion: {
      query: getLatestAiAgentVersion,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.project?.aiAgent ?? {};
      },
      error(error) {
        this.errorMessage = error.message;
        Sentry.captureException(error);
      },
    },
  },
  i18n: {
    updateAgent: s__('AIAgent|Update agent'),
    saveError: s__('AIAgents|An error has occurred when saving the agent.'),
    notFoundError: s__('AIAgents|The requested agent was not found.'),
    destroyError: s__('AIAgents|An error has occurred when deleting the agent.'),
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.latestAgentVersion.loading;
    },
    queryVariables() {
      return {
        fullPath: this.projectPath,
        agentId: `gid://gitlab/Ai::Agent/${this.$route.params.agentId}`,
      };
    },
    agentVersionNotFound() {
      return this.latestAgentVersion && Object.keys(this.latestAgentVersion).length === 0;
    },
  },
  methods: {
    async updateAgent(requestData) {
      this.errorMessage = '';
      this.loading = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateAiAgent,
          variables: requestData,
        });

        this.loading = false;

        const [error] = data?.aiAgentUpdate?.errors || [];

        if (error) {
          this.errorMessage = data.aiAgentUpdate.errors.join(', ');
        } else {
          this.$router.push({
            name: 'show',
            params: { agentId: data?.aiAgentUpdate?.agent?.routeId },
          });
        }
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = this.$options.i18n.saveError;
        this.loading = false;
      }
    },
    async destroyAgent(requestData) {
      this.errorMessage = '';
      this.loading = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: destroyAiAgent,
          variables: requestData,
        });

        this.loading = false;

        const [error] = data?.aiAgentDestroy?.errors || [];

        if (error) {
          this.errorMessage = data.aiAgentDestroy.errors.join(', ');
        } else {
          eventHub.$emit('agents-changed');
          this.$router.push({
            name: 'list',
          });
        }
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = this.$options.i18n.destroyError;
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />

    <gl-alert v-else-if="errorMessage" :dismissible="false" variant="danger" class="gl-mb-3">
      {{ errorMessage }}
    </gl-alert>

    <gl-empty-state v-else-if="agentVersionNotFound" :title="$options.i18n.notFoundError" />

    <div v-else>
      <title-area>
        <template #title>
          <div class="gl-flex gl-grow gl-items-center">
            <span>{{ s__('AIAgents|Agent Settings') }}</span>
            <gl-experiment-badge />
          </div>
        </template>
      </title-area>

      <p class="gl-text-subtle">
        {{ s__('AIAgents|Update the name and prompt for this agent.') }}
      </p>

      <agent-form
        :project-path="projectPath"
        :agent-version="latestAgentVersion"
        :agent-name-value="latestAgentVersion.name"
        :agent-prompt-value="latestAgentVersion.latestVersion.prompt"
        :button-label="$options.i18n.updateAgent"
        :error-message="errorMessage"
        :loading="loading"
        @submit="updateAgent"
      />

      <delete-agent
        :project-path="projectPath"
        :agent-version="latestAgentVersion"
        :loading="loading"
        @destroy="destroyAgent"
      />
    </div>
  </div>
</template>
