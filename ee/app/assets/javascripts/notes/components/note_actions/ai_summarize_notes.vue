<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import { InternalEvents } from '~/tracking';

export default {
  name: 'AiSummarizeNotes',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    loading: {
      type: Boolean,
      default: false,
      required: false,
    },
    resourceGlobalId: {
      type: String,
      required: true,
    },
    size: {
      type: String,
      required: false,
      default: 'medium',
    },
    workItemType: {
      type: String,
      default: '',
      required: false,
    },
  },
  mounted() {
    this.trackEvent('render_ai_summarize_notes_button', { label: this.workItemType });
  },
  methods: {
    onClick() {
      this.hideTooltips();

      if (this.loading) {
        return;
      }

      this.trackEvent('click_ai_summarize_notes_button', { label: this.workItemType });

      sendDuoChatCommand({
        question: '/summarize_comments',
        resourceId: this.resourceGlobalId,
      });
    },
    hideTooltips() {
      this.$nextTick(() => {
        this.$root.$emit(BV_HIDE_TOOLTIP);
      });
    },
  },
};
</script>

<template>
  <gl-button
    v-gl-tooltip
    icon="duo-chat"
    :disabled="loading"
    :loading="loading"
    :size="size"
    :title="s__('AISummary|Generates a summary of this issue')"
    :aria-label="s__('AISummary|Generates a summary of this issue')"
    @click="onClick"
    @mouseout="hideTooltips"
  >
    {{ s__('AISummary|View summary') }}
  </gl-button>
</template>
