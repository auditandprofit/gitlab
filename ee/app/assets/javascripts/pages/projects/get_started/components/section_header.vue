<script>
import { GlIcon, GlButton } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { ICON_TYPE_EMPTY, ICON_TYPE_PARTIAL, ICON_TYPE_COMPLETED } from '../constants';

export default {
  name: 'SectionHeader',
  components: {
    GlIcon,
    GlButton,
  },
  props: {
    section: {
      required: true,
      type: Object,
    },
    isExpanded: {
      required: true,
      type: Boolean,
    },
    sectionIndex: {
      type: Number,
      required: true,
    },
  },
  emits: ['toggle-expand'],
  computed: {
    allActions() {
      const { actions = [], trialActions = [] } = this.section;
      return [...actions, ...trialActions];
    },

    actionCounts() {
      const { actions = [], trialActions = [] } = this.section;

      const completedActions = actions.filter((action) => action.completed).length;
      const completedTrialActions = trialActions.filter((action) => action.completed).length;

      return {
        completed: completedActions + completedTrialActions,
        total: actions.length + trialActions.length,
      };
    },

    completionText() {
      const { completed, total } = this.actionCounts;
      return sprintf(__('%{completed}/%{total} completed'), {
        completed,
        total,
      });
    },

    completionIcon() {
      if (this.allActions.length === 0) return ICON_TYPE_EMPTY;

      const { completed, total } = this.actionCounts;

      if (completed === 0) return ICON_TYPE_EMPTY;
      if (completed < total) return ICON_TYPE_PARTIAL;
      return ICON_TYPE_COMPLETED;
    },

    isAllCompleted() {
      return this.allActions.length > 0 && this.allActions.every((action) => action.completed);
    },

    expandButtonLabel() {
      return this.isExpanded ? __('Collapse') : __('Expand');
    },

    expandButtonIcon() {
      return this.isExpanded ? 'chevron-up' : 'chevron-down';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-h-6 gl-items-center gl-gap-3">
    <gl-icon ref="icon" variant="default" :name="completionIcon" />
    <span
      class="gl-flex-1"
      data-testid="section-title"
      :class="{ 'gl-line-through': isAllCompleted }"
    >
      {{ section.title }}
    </span>
    <div class="gl-text-subtle" data-testid="completion-text">{{ completionText }}</div>
    <gl-button
      size="medium"
      category="tertiary"
      :icon="expandButtonIcon"
      :aria-label="expandButtonLabel"
      :data-testid="`section-header-${sectionIndex}`"
      @click="$emit('toggle-expand')"
    />
  </div>
</template>
