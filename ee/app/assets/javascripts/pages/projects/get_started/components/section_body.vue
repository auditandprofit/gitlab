<script>
import { GlIcon, GlCollapse } from '@gitlab/ui';
import ActionItem from './action_item.vue';

export default {
  name: 'SectionBody',
  components: {
    GlIcon,
    GlCollapse,
    ActionItem,
  },
  props: {
    section: {
      type: Object,
      required: true,
    },
    isExpanded: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    showDivider() {
      return Boolean(this.section.trialActions?.length);
    },
  },
};
</script>

<template>
  <gl-collapse :visible="isExpanded" class="gl-flex gl-flex-col">
    <div class="gl-my-4 gl-flex gl-items-center gl-gap-2">
      <gl-icon
        v-if="section.descriptionIcon"
        variant="default"
        :name="section.descriptionIcon"
        data-testid="description-icon"
      />
      <span class="gl-text-subtle" data-testid="description-text">{{ section.description }}</span>
    </div>

    <!-- Action list -->
    <ul class="gl-mb-4 gl-flex gl-list-none gl-flex-col gl-gap-4 gl-pl-0">
      <action-item
        v-for="(action, index) in section.actions"
        :key="`action-${index}`"
        data-testid="action-item"
        :action="action"
      />

      <!-- Trial section divider -->
      <li v-if="showDivider" class="gl-mb-1 gl-mt-2">
        <div
          class="gl-mb-4 gl-border-b-1 gl-border-gray-100 gl-border-b-solid"
          data-testid="divider"
        ></div>
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-icon variant="default" name="license" data-testid="trial-icon" />
          <span class="gl-text-subtle" data-testid="trial-description-text">{{
            s__('LearnGitLab|Included in trial')
          }}</span>
        </div>
      </li>

      <!-- Trial actions -->
      <action-item
        v-for="(action, index) in section.trialActions"
        :key="`trial-${index}`"
        data-testid="trial-action-item"
        :action="action"
      />
    </ul>
  </gl-collapse>
</template>
