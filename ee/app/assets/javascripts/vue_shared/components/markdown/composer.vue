<script>
import { v4 as uuidv4 } from 'uuid';
import { GlButton, GlFormInput, GlFormGroup, GlSkeletonLoader } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { updateText } from '~/lib/utils/text_markdown';
import eventHub from '~/vue_shared/components/markdown/eventhub';

export default {
  name: 'MarkdownComposer',
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      composer: {
        query: aiResponseSubscription,
        variables() {
          return {
            resourceId: this.resourceId,
            userId: this.userId,
            htmlResponse: true,
            clientSubscriptionId: this.composerSubscriptionID,
          };
        },
        result({ data }) {
          if (!data.aiCompletionResponse) return;

          const { content, contentHtml } = data.aiCompletionResponse;

          this.aiContentPreview = content;
          this.aiContentPreviewHTML = contentHtml;
          this.aiContentPreviewLoading = false;
        },
      },
    },
  },
  directives: { SafeHtml },
  components: { GlButton, GlFormInput, GlFormGroup, GlSkeletonLoader },
  mixins: [InternalEvents.mixin()],
  inject: ['projectId', 'sourceBranch', 'targetBranch'],
  props: {
    markdown: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      userPrompt: '',
      showComposer: false,
      aiContentPreviewLoading: false,
      aiContentPreview: null,
      aiContentPreviewHTML: null,
      cursorLocation: 0,
      top: 0,
    };
  },
  computed: {
    resourceId() {
      return convertToGraphQLId(TYPENAME_PROJECT, this.projectId);
    },
    userId() {
      return convertToGraphQLId(TYPENAME_USER, gon.current_user_id);
    },
    cursorText() {
      return this.markdown.substring(0, this.cursorLocation);
    },
    cursorAfterText() {
      return this.markdown.substring(this.cursorLocation);
    },
    composerSubscriptionID() {
      return `composer-${uuidv4()}`;
    },
  },
  mounted() {
    document.addEventListener('keyup', this.onDocumentKeyUp);

    eventHub.$on('SHOW_COMPOSER', this.showComposerPopover);
    eventHub.$on('CLOSE_COMPOSER', this.closeComposerPopover);

    this.textarea = this.$el.querySelector('textarea');

    if (this.textarea) {
      this.textarea.addEventListener('mouseup', this.onKeyUp);
      this.textarea.addEventListener('keyup', this.onKeyUp);
      this.textarea.addEventListener('scroll', this.onScroll);
    }
  },
  beforeDestroy() {
    document.removeEventListener('keyup', this.onDocumentKeyUp);

    eventHub.$off('SHOW_COMPOSER', this.showComposerPopover);
    eventHub.$off('CLOSE_COMPOSER', this.closeComposerPopover);

    if (this.textarea) {
      this.textarea.removeEventListener('mouseup', this.onKeyUp);
      this.textarea.removeEventListener('keyup', this.onKeyUp);
      this.textarea.removeEventListener('scroll', this.onScroll);
    }
  },
  methods: {
    showComposerPopover() {
      this.showComposer = true;
    },
    closeComposerPopover() {
      this.showComposer = false;
      this.discardAIContent();
    },
    onDocumentKeyUp(e) {
      if (this.showComposer && e.key === 'Escape') {
        this.closeComposerPopover();
      }
    },
    onKeyUp() {
      this.cursorLocation = this.textarea.selectionEnd;
      this.calculateTop();
    },
    onScroll() {
      this.$refs.textContainer.scrollTo(0, this.textarea.scrollTop);
      this.calculateTop();
    },
    calculateTop() {
      this.$nextTick(() => {
        const top =
          this.$refs.text.offsetTop + this.$refs.text.offsetHeight - this.textarea.scrollTop;

        this.top = Math.min(this.textarea.offsetHeight, Math.max(0, top)) + 8;
      });
    },
    submitComposer() {
      let description = this.markdown || '';
      description = `${description.slice(
        0,
        this.textarea?.selectionStart || 0,
      )}<selected-text>${description.slice(
        this.textarea?.selectionStart || 0,
        this.textarea?.selectionEnd || 0,
      )}</selected-text>${description.slice(this.textarea?.selectionEnd || 0)}`;

      this.aiContentPreviewLoading = true;

      this.$apollo.mutate({
        mutation: aiActionMutation,
        variables: {
          input: {
            descriptionComposer: {
              resourceId: this.resourceId,
              sourceProjectId: this.projectId,
              sourceBranch: this.sourceBranch,
              targetBranch: this.targetBranch,
              description,
              title: document.querySelector('.js-issuable-title')?.value ?? '',
              userPrompt: this.userPrompt || '',
              previousResponse: this.aiContentPreview ?? '',
            },
            clientSubscriptionId: this.composerSubscriptionID,
          },
        },
      });
    },
    insertAiContent() {
      updateText({
        textArea: this.textarea,
        tag: this.aiContentPreview,
        cursorOffset: 0,
        wrap: false,
        replaceText: true,
      });

      this.closeComposerPopover();
    },
    discardAIContent() {
      this.aiContentPreview = null;
      this.aiContentPreviewHTML = null;
      this.userPrompt = '';
    },
  },
};
</script>

<template>
  <div class="gl-relative">
    <slot></slot>
    <div
      class="gl-absolute gl-bottom-0 gl-left-0 gl-right-0 gl-top-[-2px] gl-overflow-auto gl-overflow-x-hidden gl-border-2 gl-border-solid gl-border-transparent gl-px-[14px] gl-py-[12px]"
    >
      <div ref="textContainer">
        <!-- prettier-ignore -->
        <div 
            class="gfm-input-text markdown-area gl-invisible !gl-font-monospace gl-whitespace-pre-wrap gl-border-0 gl-p-0 !gl-max-h-fit"
            style="word-wrap: break-word">{{ cursorText }}<span ref="text">|</span>{{ cursorAfterText }}</div>
      </div>
    </div>
    <div
      v-if="showComposer"
      class="gl-absolute gl-left-5 gl-right-5 gl-top-0 gl-z-4 gl-overflow-hidden gl-rounded-lg gl-border-1 gl-border-solid gl-border-dropdown gl-bg-dropdown gl-shadow-md"
      :class="{ 'gl-pt-0': aiContentPreview }"
      :style="`top: ${top}px`"
    >
      <div
        v-if="aiContentPreviewLoading || aiContentPreview"
        class="gl-border-b-1 gl-border-dropdown gl-bg-gray-50 gl-p-4 gl-border-b-solid"
      >
        <gl-skeleton-loader v-if="aiContentPreviewLoading" :lines="3" />
        <div
          v-else-if="aiContentPreview"
          v-safe-html="aiContentPreview"
          class="md gl-max-h-[200px] gl-overflow-y-auto gl-whitespace-pre-wrap gl-font-monospace"
        ></div>
      </div>
      <div class="gl-p-4">
        <gl-form-group
          :label="__('Describe what you want to write')"
          label-for="composer-user-prompt"
        >
          <gl-form-input
            id="composer-user-prompt"
            v-model="userPrompt"
            :placeholder="
              __('Ask GitLab Duo to help you write descriptions, rewrite existing text and more...')
            "
            autocomplete="off"
            autofocus
            data-testid="composer-user-prompt"
            :disabled="aiContentPreviewLoading"
            @keydown.enter.prevent.stop="submitComposer"
          />
        </gl-form-group>
        <div class="gl-flex gl-justify-end gl-gap-3">
          <gl-button
            v-if="aiContentPreview"
            variant="danger"
            category="tertiary"
            data-testid="composer-discard"
            @click="discardAIContent"
            >{{ s__('AI|Discard suggestion') }}</gl-button
          >
          <gl-button
            :variant="aiContentPreview ? 'default' : 'confirm'"
            :loading="aiContentPreviewLoading"
            data-testid="composer-submit"
            @click="submitComposer"
          >
            <template v-if="aiContentPreview">{{ s__('AI|Regenerate') }}</template>
            <template v-else>{{ s__('AI|Generate') }}</template>
          </gl-button>
          <gl-button
            v-if="aiContentPreview"
            variant="confirm"
            data-testid="composer-insert"
            @click="insertAiContent"
            >{{ s__('AI|Accept & Insert') }}</gl-button
          >
        </div>
      </div>
    </div>
  </div>
</template>
