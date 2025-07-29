<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { DuoChat } from '@gitlab/duo-ui';
import { GlToggle } from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';
import { __, s__ } from '~/locale';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { helpPagePath } from '~/helpers/help_page_helper';
import { getCookie } from '~/lib/utils/common_utils';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { clearDuoChatCommands, generateEventLabelFromText, setAgenticMode } from 'ee/ai/utils';
import DuoChatCallout from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import getAiMessages from 'ee/ai/graphql/get_ai_messages.query.graphql';
import getAiConversationThreads from 'ee/ai/graphql/get_ai_conversation_threads.query.graphql';
import getAiMessagesWithThread from 'ee/ai/graphql/get_ai_messages_with_thread.query.graphql';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import chatWithNamespaceMutation from 'ee/ai/graphql/chat_with_namespace.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import { InternalEvents } from '~/tracking';
import deleteConversationThreadMutation from 'ee/ai/graphql/delete_conversation_thread.mutation.graphql';
import {
  i18n,
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_CHAT_VIEWS,
} from 'ee/ai/constants';
import getAiSlashCommands from 'ee/ai/graphql/get_ai_slash_commands.query.graphql';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { fetchPolicies } from '~/lib/graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import {
  TANUKI_BOT_TRACKING_EVENT_NAME,
  MESSAGE_TYPES,
  WIDTH_OFFSET,
  MULTI_THREADED_CONVERSATION_TYPE,
  DUO_AGENTIC_MODE_COOKIE,
} from '../constants';
import TanukiBotSubscriptions from './tanuki_bot_subscriptions.vue';

export default {
  name: 'TanukiBotChatApp',
  i18n: {
    gitlabChat: s__('DuoChat|GitLab Duo Chat'),
    giveFeedback: s__('DuoChat|Give feedback'),
    source: __('Source'),
    experiment: __('Experiment'),
    askAQuestion: s__('DuoChat|Ask a question about GitLab'),
    exampleQuestion: s__('DuoChat|For example, %{linkStart}what is a fork%{linkEnd}?'),
    whatIsAForkQuestion: s__('DuoChat|What is a fork?'),
    newSlashCommandDescription: s__('DuoChat|New chat conversation.'),
    GENIE_CHAT_LEGAL_GENERATED_BY_AI: i18n.GENIE_CHAT_LEGAL_GENERATED_BY_AI,
  },
  helpPagePath: helpPagePath('policy/development_stages_support', { anchor: 'beta' }),
  components: {
    DuoChat,
    DuoChatCallout,
    TanukiBotSubscriptions,
    GlToggle,
  },
  mixins: [InternalEvents.mixin(), glFeatureFlagsMixin()],
  provide() {
    return {
      renderGFM,
    };
  },
  props: {
    userId: {
      type: String,
      required: true,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    projectId: {
      type: String,
      required: false,
      default: null,
    },
    rootNamespaceId: {
      type: String,
      required: false,
      default: null,
    },
    chatTitle: {
      type: String,
      required: false,
      default: null,
    },
    agenticAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    aiMessages: {
      query: getAiMessages,
      variables() {
        return {
          conversationType: 'DUO_CHAT',
        };
      },
      skip() {
        return !this.duoChatGlobalState.isShown;
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      result({ data }) {
        if (data?.aiMessages?.nodes) {
          this.setMessages(data.aiMessages.nodes);
        }
      },
      error(err) {
        this.onError(err);
      },
    },
    aiConversationThreads: {
      query: getAiConversationThreads,
      skip() {
        return !this.duoChatGlobalState.isShown;
      },
      update(data) {
        return data?.aiConversationThreads?.nodes || [];
      },
      error(err) {
        this.onError(err);
      },
    },
    aiSlashCommands: {
      query: getAiSlashCommands,
      skip() {
        return !this.duoChatGlobalState.isShown;
      },
      variables() {
        return {
          url: typeof window !== 'undefined' && window.location ? window.location.href : '',
        };
      },
      update(data) {
        return data?.aiSlashCommands || [];
      },
      error(err) {
        this.onError(err);
      },
    },
    contextPresets: {
      query: getAiChatContextPresets,
      skip() {
        return !this.duoChatGlobalState.isShown;
      },
      variables() {
        return {
          resourceId: this.resourceId,
          projectId: this.projectId,
          url: typeof window !== 'undefined' && window.location ? window.location.href : '',
          questionCount: 4,
        };
      },
      update(data) {
        return data?.aiChatContextPresets?.questions || [];
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  data() {
    return {
      duoChatGlobalState,
      clientSubscriptionId: uuidv4(),
      toolName: i18n.GITLAB_DUO,
      error: '',
      isResponseTracked: false,
      cancelledRequestIds: [],
      completedRequestId: null,
      aiSlashCommands: [],
      width: 400,
      height: window.innerHeight,
      minWidth: 400,
      minHeight: 400,
      // Explicitly initializing `left` as null to ensure Vue makes it reactive.
      // This allows computed properties and watchers dependent on `left` to work correctly.
      left: null,
      activeThread: undefined,
      multithreadedView: DUO_CHAT_VIEWS.CHAT,
      aiConversationThreads: [],
      contextPresets: [],
    };
  },
  computed: {
    ...mapState(['loading', 'messages']),
    duoAgenticModePreference: {
      get() {
        return getCookie(DUO_AGENTIC_MODE_COOKIE) === 'true';
      },
      set(value) {
        setAgenticMode(value, true);
      },
    },
    computedResourceId() {
      if (this.hasCommands) {
        return this.duoChatGlobalState.commands[0].resourceId;
      }

      return this.resourceId || this.userId;
    },
    shouldRenderResizable() {
      return this.glFeatures.duoChatDynamicDimension;
    },
    dimensions() {
      return {
        width: this.width,
        height: this.height,
        top: this.top,
        maxHeight: this.maxHeight,
        maxWidth: this.maxWidth,
        minWidth: this.minWidth,
        minHeight: this.minHeight,
        left: this.left,
      };
    },
    hasCommands() {
      return this.duoChatGlobalState.commands.length > 0;
    },
    predefinedPrompts() {
      return this.contextPresets;
    },
    formattedContextPresets() {
      return this.contextPresets.map((question) => ({
        text: question,
        eventLabel: generateEventLabelFromText(question),
      }));
    },
  },
  watch: {
    'duoChatGlobalState.isShown': {
      handler(newVal) {
        if (!newVal) {
          // we reset chat when it gets closed, to avoid flickering the previously opened thread
          // information when it's opened again
          this.onNewChat();
        }
      },
    },
    'duoChatGlobalState.commands': {
      handler(newVal) {
        if (newVal.length) {
          const { commands } = this.duoChatGlobalState;
          if (commands.length) {
            this.onNewChat();
            const { question, variables, resourceId } = commands[0];
            this.onSendChatPrompt(question, variables, resourceId);
          }
        }
      },
    },
  },
  mounted() {
    this.setDimensions();
    window.addEventListener('resize', this.onWindowResize);
  },
  beforeDestroy() {
    // Remove the event listener when the component is destroyed
    window.removeEventListener('resize', this.onWindowResize);
  },
  methods: {
    ...mapActions(['addDuoChatMessage', 'setMessages', 'setLoading']),
    setDimensions() {
      this.updateDimensions();
    },
    updateDimensions(width, height) {
      this.maxWidth = window.innerWidth - WIDTH_OFFSET;
      this.maxHeight = window.innerHeight;

      this.width = Math.min(width || this.width, this.maxWidth);
      this.height = Math.min(height || this.height, this.maxHeight);
      this.top = window.innerHeight - this.height;
      this.left = window.innerWidth - this.width;
    },
    onChatResize(e) {
      this.updateDimensions(e.width, e.height);
    },
    onWindowResize() {
      this.updateDimensions();
    },
    shouldStartNewChat(question) {
      return [GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE, GENIE_CHAT_RESET_MESSAGE].includes(
        question,
      );
    },
    findPredefinedPrompt(question) {
      return this.formattedContextPresets.find(({ text }) => text === question);
    },
    async onThreadSelected(e) {
      try {
        const { data } = await this.$apollo.query({
          query: getAiMessagesWithThread,
          variables: { threadId: e.id },
          fetchPolicy: 'network-only',
        });

        if (data?.aiMessages?.nodes?.length > 0) {
          this.setMessages(data.aiMessages.nodes);
          this.multithreadedView = DUO_CHAT_VIEWS.CHAT;
          this.activeThread = e.id;
        }
      } catch (err) {
        this.onError(err);
      }
    },
    onNewChat() {
      clearDuoChatCommands();
      this.activeThread = undefined;
      this.setMessages([]);
      this.multithreadedView = DUO_CHAT_VIEWS.CHAT;
      this.setLoading(false);
      this.completedRequestId = null;
      this.cancelledRequestIds = [];
    },
    onChatCancel() {
      // pushing last requestId of messages to canceled Request Id's
      this.cancelledRequestIds.push(this.messages[this.messages.length - 1].requestId);
      this.setLoading(false);
    },
    onMessageReceived(aiCompletionResponse) {
      this.addDuoChatMessage(aiCompletionResponse);
      if (aiCompletionResponse.role.toLowerCase() === MESSAGE_TYPES.TANUKI) {
        this.completedRequestId = aiCompletionResponse.requestId;
        clearDuoChatCommands();
      }
    },
    onMessageStreamReceived(aiCompletionResponse) {
      if (aiCompletionResponse.requestId !== this.completedRequestId) {
        this.addDuoChatMessage(aiCompletionResponse);
      }
    },
    onResponseReceived(requestId) {
      if (this.isResponseTracked) {
        return;
      }

      performance.mark('response-received');
      performance.measure('prompt-to-response', 'prompt-sent', 'response-received');
      const [{ duration }] = performance.getEntriesByName('prompt-to-response');

      this.trackEvent('ai_response_time', {
        property: requestId,
        value: parseFloat(duration) || 0,
      });

      performance.clearMarks();
      performance.clearMeasures();
      this.isResponseTracked = true;
    },
    onSendChatPrompt(question, variables = {}, resourceId = this.computedResourceId) {
      if (this.shouldStartNewChat(question)) {
        this.onNewChat();
        return;
      }

      performance.mark('prompt-sent');
      this.completedRequestId = null;
      this.isResponseTracked = false;

      if (!this.loading) {
        this.setLoading(true);
      }

      const mutationName = this.rootNamespaceId ? chatWithNamespaceMutation : chatMutation;
      const mutationVariables = {
        question,
        resourceId,
        clientSubscriptionId: this.clientSubscriptionId,
        projectId: this.projectId,
        threadId: this.activeThread,
        conversationType: MULTI_THREADED_CONVERSATION_TYPE,
        ...(this.rootNamespaceId && { rootNamespaceId: this.rootNamespaceId }),
        ...variables,
      };

      this.$apollo
        .mutate({
          mutation: mutationName,
          variables: mutationVariables,
          context: {
            headers: {
              'X-GitLab-Interface': 'duo_chat',
              'X-GitLab-Client-Type': 'web_browser',
            },
          },
        })
        .then(({ data: { aiAction = {} } = {} }) => {
          const trackingOptions = {
            property: aiAction.requestId,
            label: this.findPredefinedPrompt(question)?.eventLabel,
          };

          this.trackEvent('submit_gitlab_duo_question', trackingOptions);

          if (aiAction.threadId && !this.activeThread) {
            this.activeThread = aiAction.threadId;
          }

          this.addDuoChatMessage({
            ...aiAction,
            content: question,
          });
        })
        .catch((err) => {
          this.addDuoChatMessage({
            content: question,
          });
          this.onError(err);
          this.setLoading(false);
        });
    },
    onChatClose() {
      this.duoChatGlobalState.isShown = false;
    },
    onCalloutDismissed() {
      this.duoChatGlobalState.isShown = true;
    },
    onTrackFeedback({ feedbackChoices, didWhat, improveWhat, message } = {}) {
      if (message) {
        const { id, requestId, extras, role, content } = message;
        this.$apollo
          .mutate({
            mutation: duoUserFeedbackMutation,
            variables: {
              input: {
                aiMessageId: id,
                trackingEvent: {
                  category: TANUKI_BOT_TRACKING_EVENT_NAME,
                  action: 'duo_chat',
                  label: 'response_feedback',
                  property: feedbackChoices.join(','),
                  extra: {
                    improveWhat,
                    didWhat,
                    prompt_location: 'after_content',
                  },
                },
              },
            },
          })
          .catch(() => {
            // silent failure because of fire and forget
          });

        this.addDuoChatMessage({
          requestId,
          role,
          content,
          extras: { ...extras, hasFeedback: true },
        });
      }
    },
    onError(err) {
      this.addDuoChatMessage({ errors: [err.toString()] });
    },
    onBackToList() {
      this.multithreadedView = DUO_CHAT_VIEWS.LIST;
      this.activeThread = undefined;
      this.setMessages([]);
      this.$apollo.queries.aiConversationThreads.refetch();
    },
    onDeleteThread(threadId) {
      this.$apollo
        .mutate({
          mutation: deleteConversationThreadMutation,
          variables: { input: { threadId } },
        })
        .then(({ data }) => {
          if (data?.deleteConversationThread?.success) {
            this.$apollo.queries.aiConversationThreads.refetch();
          } else {
            const errors = data?.deleteConversationThread?.errors;
            this.onError(new Error(errors.join(', ')));
          }
        })
        .catch(this.onError);
    },
  },
};
</script>

<template>
  <div>
    <div v-if="duoChatGlobalState.isShown">
      <!-- Renderless component for subscriptions -->
      <tanuki-bot-subscriptions
        :user-id="userId"
        :client-subscription-id="clientSubscriptionId"
        :cancelled-request-ids="cancelledRequestIds"
        :active-thread-id="activeThread"
        @message="onMessageReceived"
        @message-stream="onMessageStreamReceived"
        @response-received="onResponseReceived"
        @error="onError"
      />

      <duo-chat
        id="duo-chat"
        :thread-list="aiConversationThreads"
        :multi-threaded-view="multithreadedView"
        :active-thread-id="activeThread"
        :is-multithreaded="true"
        :slash-commands="aiSlashCommands"
        :title="chatTitle"
        :dimensions="dimensions"
        :messages="messages"
        :error="error"
        :is-loading="loading"
        :should-render-resizable="shouldRenderResizable"
        :predefined-prompts="predefinedPrompts"
        :badge-type="null"
        :tool-name="toolName"
        :canceled-request-ids="cancelledRequestIds"
        class="duo-chat-container"
        @thread-selected="onThreadSelected"
        @new-chat="onNewChat"
        @back-to-list="onBackToList"
        @delete-thread="onDeleteThread"
        @chat-cancel="onChatCancel"
        @send-chat-prompt="onSendChatPrompt"
        @chat-hidden="onChatClose"
        @track-feedback="onTrackFeedback"
        @chat-resize="onChatResize"
        ><template v-if="agenticAvailable" #footer-controls>
          <div class="gl-flex gl-px-4 gl-pb-2 gl-pt-5">
            <gl-toggle
              v-model="duoAgenticModePreference"
              :label="s__('DuoChat|Agentic mode (Beta)')"
              label-position="left"
            />
          </div>
        </template>
      </duo-chat>
    </div>
    <duo-chat-callout @callout-dismissed="onCalloutDismissed" />
  </div>
</template>
