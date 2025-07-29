<script>
import { LINE_CHANGE_SYMBOLS } from 'ee/analytics/merge_request_analytics/constants';

export default {
  name: 'DiffLineChanges',
  props: {
    additions: {
      type: Number,
      required: false,
      default: 0,
    },
    deletions: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    formattedAdditions() {
      return `${LINE_CHANGE_SYMBOLS.ADDITIONS}${this.additions}`;
    },
    formattedDeletions() {
      return `${LINE_CHANGE_SYMBOLS.DELETIONS}${this.deletions}`;
    },
  },
};
</script>
<template>
  <div>
    <span class="gl-font-bold gl-text-success">{{ formattedAdditions }}</span>
    <span class="gl-font-bold gl-text-red-500">{{ formattedDeletions }}</span>
  </div>
</template>
