<script>
/*
 * This component shows a icon if issue is a child of child epic
 * filtered by epic id.
 */
import { GlIcon, GlTooltipDirective as GlTooltip } from '@gitlab/ui';

export default {
  components: {
    GlIcon,
  },
  directives: {
    GlTooltip,
  },
  props: {
    filteredEpicId: {
      type: String,
      required: true,
    },
    issuable: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isChildEpicIssue() {
      return this.issuable.epic?.id !== this.filteredEpicId;
    },
  },
};
</script>
<template>
  <span
    v-if="isChildEpicIssue"
    v-gl-tooltip
    data-testid="child-epic-issue-indicator"
    :title="__('This issue is in a child epic of the filtered epic')"
    class="gl-ml-1 gl-inline-block"
  >
    <gl-icon name="file-tree" variant="subtle" />
  </span>
</template>
