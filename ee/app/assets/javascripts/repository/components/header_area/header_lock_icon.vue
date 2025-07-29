<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    isTreeView: {
      type: Boolean,
      required: true,
      default: true,
    },
    isLocked: {
      type: Boolean,
      required: true,
      default: false,
    },
    lockAuthor: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  computed: {
    lockTypeText() {
      return this.isTreeView ? __('Directory locked') : __('File locked');
    },
    lockIconTooltip() {
      return this.lockAuthor
        ? `${this.lockTypeText} ${__('by')} ${this.lockAuthor}`
        : this.lockTypeText;
    },
  },
};
</script>

<template>
  <gl-button
    v-if="glFeatures.repositoryLockInformation && isLocked"
    v-gl-tooltip
    :title="lockIconTooltip"
    :aria-label="lockIconTooltip"
    category="tertiary"
    variant="default"
    icon="lock"
  />
</template>
