<script>
import { GlExperimentBadge } from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import AgentForm from '../components/agent_form.vue';
import createAiAgent from '../graphql/mutations/create_ai_agent.mutation.graphql';
import { I18N_CREATE_AGENT, I18N_DEFAULT_SAVE_ERROR } from '../constants';

export default {
  name: 'CreateAiAgent',
  components: {
    TitleArea,
    GlExperimentBadge,
    AgentForm,
  },
  I18N_CREATE_AGENT,
  I18N_DEFAULT_SAVE_ERROR,
  inject: ['projectPath'],
  data() {
    return {
      errorMessage: '',
      loading: false,
    };
  },
  helpPagePath: helpPagePath('policy/development_stages_support', { anchor: 'experiment' }),
  methods: {
    async createAgent(requestData) {
      this.errorMessage = '';
      this.loading = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiAgent,
          variables: requestData,
        });

        this.loading = false;

        const [error] = data?.aiAgentCreate?.errors || [];

        if (error) {
          this.errorMessage = data.aiAgentCreate.errors.join(', ');
        } else {
          this.$router.push({
            name: 'show',
            params: { agentId: data?.aiAgentCreate?.agent?.routeId },
          });
        }
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = this.$options.I18N_DEFAULT_SAVE_ERROR;
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <title-area>
      <template #title>
        <div class="gl-flex gl-grow gl-items-center">
          <span>{{ s__('AIAgents|New agent') }}</span>
          <gl-experiment-badge />
        </div>
      </template>
    </title-area>

    <agent-form
      :project-path="projectPath"
      :button-label="$options.I18N_CREATE_AGENT"
      :error-message="errorMessage"
      :loading="loading"
      @submit="createAgent"
    />
  </div>
</template>
