<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { AgenticDuoChat } from '@gitlab/duo-ui';
import { GlToggle } from '@gitlab/ui';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { getCookie } from '~/lib/utils/common_utils';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { clearDuoChatCommands, setAgenticMode } from 'ee/ai/utils';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import { parseGid } from '~/graphql_shared/utils';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_CLIENT_VERSION,
  DUO_WORKFLOW_AGENT_PRIVILEGES,
  DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
  DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
  DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
  CHAT_MESSAGE_TYPES,
  GENIE_CHAT_MODEL_ROLES,
} from 'ee/ai/constants';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import { createWebSocket, parseMessage, closeSocket } from '~/lib/utils/websocket_utils';
import { WIDTH_OFFSET, DUO_AGENTIC_MODE_COOKIE } from '../../tanuki_bot/constants';

export default {
  name: 'DuoAgenticChatApp',
  components: {
    AgenticDuoChat,
    GlToggle,
  },
  provide() {
    return {
      renderGFM,
    };
  },
  props: {
    projectId: {
      type: String,
      required: false,
      default: null,
    },
    namespaceId: {
      type: String,
      required: false,
      default: null,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    metadata: {
      type: String,
      required: false,
      default: null,
    },
  },
  apollo: {
    contextPresets: {
      query: getAiChatContextPresets,
      skip() {
        return !this.duoChatGlobalState.isAgenticChatShown;
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
        return data?.aiChatContextPresets || {};
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  data() {
    return {
      duoChatGlobalState,
      width: 550,
      height: window.innerHeight,
      minWidth: 550,
      minHeight: 400,
      // Explicitly initializing the props as null to ensure Vue makes it reactive.
      left: null,
      top: null,
      maxHeight: null,
      maxWidth: null,
      contextPresets: [],
      socketManager: null,
      workflowId: null,
      workflowStatus: null,
      isProcessingToolApproval: false,
    };
  },
  computed: {
    ...mapState(['loading', 'messages']),
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
    predefinedPrompts() {
      return this.contextPresets.questions || [];
    },
    additionalContext() {
      if (!this.contextPresets.aiResourceData) {
        return null;
      }

      return [
        {
          content: this.contextPresets.aiResourceData,
          // This field depends on INCLUDE_{CATEGORY}_CONTEXT unit primitive:
          // https://gitlab.com/gitlab-org/cloud-connector/gitlab-cloud-connector/-/blob/main/src/python/gitlab_cloud_connector/data_model/gitlab_unit_primitives.py?ref_type=heads#L37-47
          // Since there is no unit primitives for all resource types and there is no a general one, let's use the one for repository
          category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
          metadata: JSON.stringify({}), // This field is expected to be non-null json object
        },
      ];
    },
    duoAgenticModePreference: {
      get() {
        return getCookie(DUO_AGENTIC_MODE_COOKIE) === 'true';
      },
      set(value) {
        setAgenticMode(value, true);
      },
    },
  },
  watch: {
    'duoChatGlobalState.isAgenticChatShown': {
      handler(newVal) {
        if (!newVal) {
          // we reset chat when it gets closed, to avoid flickering the previously opened thread
          // information when it's opened again
          this.onNewChat();
        }
      },
    },
    workflowStatus(newStatus, oldStatus) {
      if (
        oldStatus === DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED &&
        newStatus !== DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED
      ) {
        this.isProcessingToolApproval = false;
      }
    },
  },
  mounted() {
    this.setDimensions();
    window.addEventListener('resize', this.onWindowResize);
  },
  beforeDestroy() {
    // Remove the event listener when the component is destroyed
    window.removeEventListener('resize', this.onWindowResize);
    this.cleanupSocket();
  },
  methods: {
    ...mapActions(['addDuoChatMessage', 'setMessages', 'setLoading']),

    cleanupSocket() {
      if (this.socketManager) {
        closeSocket(this.socketManager);
        this.socketManager = null;
      }
    },

    cleanupState(resetWorkflowId = true) {
      this.setLoading(false);
      this.cleanupSocket();
      if (resetWorkflowId) {
        this.workflowId = null;
      }
      this.workflowStatus = null;
    },

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
    onNewChat() {
      clearDuoChatCommands();
      this.setMessages([]);
      this.cleanupState();
    },
    onChatCancel() {
      this.cleanupState(false);
    },
    startWorkflow(goal, approval = {}, additionalContext) {
      this.cleanupSocket();

      const startRequest = {
        startRequest: {
          workflowID: this.workflowId,
          clientVersion: DUO_WORKFLOW_CLIENT_VERSION,
          workflowDefinition: DUO_WORKFLOW_CHAT_DEFINITION,
          workflowMetadata: this.metadata,
          goal,
          approval,
        },
      };

      if (additionalContext) {
        startRequest.startRequest.additionalContext = additionalContext;
      }

      this.socketManager = createWebSocket('/api/v4/ai/duo_workflows/ws', {
        onMessage: this.onMessageReceived,
        onError: () => {
          // eslint-disable-next-line @gitlab/require-i18n-strings
          this.onError(new Error('Unable to connect to workflow service. Please try again.'));
        },
        onClose: () => {
          // Only set loading to false if we're not waiting for tool approval
          // and we don't have a pending workflow that will create a new connection
          if (this.workflowStatus !== DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED) {
            this.isProcessingToolApproval = false;
            this.setLoading(false);
          }
        },
      });

      this.socketManager.connect(startRequest);
    },

    async onMessageReceived(event) {
      try {
        const action = await parseMessage(event);

        if (!action || !action.newCheckpoint) {
          return; // No checkpoint to process
        }

        const checkpoint = JSON.parse(action.newCheckpoint.checkpoint);
        const messages = checkpoint.channel_values.ui_chat_log.map((msg, i) => {
          const requestId = `${this.workflowId}-${i}`;
          const role = [CHAT_MESSAGE_TYPES.agent, CHAT_MESSAGE_TYPES.request].includes(
            msg.message_type,
          )
            ? GENIE_CHAT_MODEL_ROLES.assistant
            : msg.message_type;

          return {
            ...msg,
            requestId,
            role,
          };
        });

        this.setMessages(messages);

        // Update workflow status and pending tool call
        this.workflowStatus = action.newCheckpoint.status;

        if (this.workflowStatus === DUO_WORKFLOW_STATUS_INPUT_REQUIRED) {
          this.setLoading(false);
        }
      } catch (err) {
        this.onError(err);
      }
    },

    async onSendChatPrompt(question) {
      if (this.shouldStartNewChat(question)) {
        this.onNewChat();
        return;
      }

      if (!this.loading) {
        this.setLoading(true);
      }

      if (!this.workflowId) {
        try {
          const { data: { aiDuoWorkflowCreate: { workflow = {} } = {} } = {} } =
            await this.$apollo.mutate({
              mutation: duoWorkflowMutation,
              variables: {
                goal: question,
                workflowDefinition: DUO_WORKFLOW_CHAT_DEFINITION,
                agentPrivileges: DUO_WORKFLOW_AGENT_PRIVILEGES,
                preApprovedAgentPrivileges: DUO_WORKFLOW_PRE_APPROVED_AGENT_PRIVILEGES,
                ...(this.projectId && { projectId: this.projectId }),
                ...(this.namespaceId && { namespaceId: this.namespaceId }),
              },
              context: {
                headers: {
                  'X-GitLab-Interface': 'duo_chat',
                  'X-GitLab-Client-Type': 'web_browser',
                },
              },
            });
          this.workflowId = parseGid(workflow.id).id;
        } catch (err) {
          this.onError(err);
          return;
        }
      }

      const requestId = `${this.workflowId}-${this.messages?.length || 0}`;

      const userMessage = { content: question, role: 'user', requestId };

      this.startWorkflow(question, {}, this.additionalContext);
      this.addDuoChatMessage(userMessage);
    },
    onChatClose() {
      this.duoChatGlobalState.isAgenticChatShown = false;
    },
    onError(err) {
      this.addDuoChatMessage({ errors: [err.toString()] });
    },
    handleApproveToolCall() {
      this.isProcessingToolApproval = true;
      this.startWorkflow('', { approval: {} }, this.additionalContext);
    },
    handleDenyToolCall(event) {
      this.isProcessingToolApproval = true;
      const message = event?.message || event;
      this.startWorkflow(
        '',
        {
          approval: undefined,
          rejection: { message },
        },
        this.additionalContext,
      );
    },
  },
};
</script>

<template>
  <div>
    <div v-if="duoChatGlobalState.isAgenticChatShown">
      <agentic-duo-chat
        id="duo-chat"
        :title="s__('DuoAgenticChat|GitLab Duo Agentic Chat')"
        :messages="messages"
        :is-loading="loading"
        :predefined-prompts="predefinedPrompts"
        :enable-code-insertion="false"
        :should-render-resizable="true"
        :with-feedback="false"
        :show-header="true"
        badge-type="beta"
        :dimensions="dimensions"
        :is-tool-approval-processing="isProcessingToolApproval"
        @new-chat="onNewChat"
        @send-chat-prompt="onSendChatPrompt"
        @chat-cancel="onChatCancel"
        @chat-hidden="onChatClose"
        @chat-resize="onChatResize"
        @approve-tool="handleApproveToolCall"
        @deny-tool="handleDenyToolCall"
        ><template #footer-controls>
          <div class="gl-flex gl-px-4 gl-pb-2 gl-pt-5">
            <gl-toggle
              v-model="duoAgenticModePreference"
              :label="s__('DuoChat|Agentic mode (Beta)')"
              label-position="left"
            />
          </div>
        </template>
      </agentic-duo-chat>
    </div>
  </div>
</template>
