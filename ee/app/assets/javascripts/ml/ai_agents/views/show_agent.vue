<script>
import { GlExperimentBadge, GlEmptyState, GlLoadingIcon, GlButton } from '@gitlab/ui';
import { DuoChat } from '@gitlab/duo-ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import { renderMarkdown } from '~/notes/utils';
import { TYPENAME_AI_AGENT } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';
import { ROUTE_AGENT_SETTINGS } from 'ee/ml/ai_agents/constants';
import getLatestAiAgentVersion from 'ee/ml/ai_agents/graphql/queries/get_latest_ai_agent_version.query.graphql';

export default {
  name: 'ShowAiAgent',
  // Needed to override the default predefined prompts
  predefinedPrompts: [],
  components: {
    TitleArea,
    GlExperimentBadge,
    DuoChat,
    GlEmptyState,
    GlLoadingIcon,
    GlButton,
  },
  ROUTE_AGENT_SETTINGS,
  provide() {
    return {
      projectPath: this.projectPath,
      userId: this.userId,
      renderMarkdown,
      renderGFM,
    };
  },
  inject: ['projectPath', 'userId'],
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    agentWithVersion: {
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
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      aiCompletionResponse: {
        query: aiResponseSubscription,
        variables() {
          return {
            userId: this.userId,
            agentVersionId: this.agentVersionGraphQLId,
            aiAction: 'CHAT',
          };
        },
        result({ data }) {
          const response = data?.aiCompletionResponse;

          if (!response) {
            return;
          }

          this.messages.push(response);

          if (response.role.toLowerCase() === GENIE_CHAT_MODEL_ROLES.assistant) {
            this.isLoading = false;
          }
        },
        error(err) {
          this.error = err.toString();
        },
      },
    },
  },
  data() {
    return {
      errorMessage: '',
      error: null,
      messages: [],
      isLoading: false,
    };
  },
  i18n: {
    not_found_error: s__('AIAgents|The requested agent was not found.'),
  },
  computed: {
    isAgentLoading() {
      return this.$apollo.queries.agentWithVersion.loading;
    },
    queryVariables() {
      return {
        fullPath: this.projectPath,
        agentId: convertToGraphQLId(TYPENAME_AI_AGENT, this.$route.params.agentId),
      };
    },
    latestVersion() {
      return this.agentWithVersion?.latestVersion;
    },
    agentVersionGraphQLId() {
      return this.latestVersion?.id;
    },
  },
  methods: {
    onSendChatPrompt(question = '') {
      this.isLoading = true;

      this.$apollo
        .mutate({
          mutation: chatMutation,
          variables: {
            question,
            resourceId: this.userId,
            agentVersionId: this.agentVersionGraphQLId,
          },
        })
        .then(() => {
          // we add the user message in the aiCompletionResponse subscription
          this.isLoading = true;
        })
        .catch((err) => {
          this.error = err.toString();
          this.isLoading = false;
        });
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isAgentLoading" size="lg" class="gl-my-5" />

    <div v-else-if="latestVersion">
      <title-area>
        <template #title>
          <div class="gl-flex gl-grow gl-items-center">
            <span>{{ agentWithVersion.name }}</span>
            <gl-experiment-badge />
          </div>
        </template>

        <template #right-actions>
          <gl-button data-testid="settings-button" :to="{ name: $options.ROUTE_AGENT_SETTINGS }">{{
            s__('AIAgent|Settings')
          }}</gl-button>
        </template>
      </title-area>

      <duo-chat
        :messages="messages"
        :error="error"
        :is-loading="isLoading"
        :predefined-prompts="$options.predefinedPrompts"
        :tool-name="s__('AIAgent|Agent')"
        class="ai-agent-chat gl-border-r gl-static !gl-w-full gl-border-transparent"
        :empty-state-title="s__('AIAgent|Try out your agent')"
        :empty-state-description="
          s__('AIAgent|Your agent\'s system prompt will be applied to the chat input.')
        "
        :chat-prompt-placeholder="s__('AIAgent|Ask your agent')"
        :show-header="false"
        @send-chat-prompt="onSendChatPrompt"
      />
    </div>

    <gl-empty-state v-else :title="$options.I18N_DEFAULT_NOT_FOUND_ERROR" />
  </div>
</template>
