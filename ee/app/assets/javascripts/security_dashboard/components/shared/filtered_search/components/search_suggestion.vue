<script>
import { GlFilteredSearchSuggestion, GlIcon, GlTruncate } from '@gitlab/ui';

export default {
  components: {
    GlFilteredSearchSuggestion,
    GlIcon,
    GlTruncate,
  },
  props: {
    /**
     * The value of the suggestion.
     * This is passed to gl-filtered-search-suggestion and used in data test ids.
     */
    value: {
      type: [String, Number],
      required: true,
    },
    text: {
      type: String,
      required: true,
    },
    selected: {
      type: Boolean,
      required: true,
    },
    truncate: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>
<template>
  <gl-filtered-search-suggestion :value="value">
    <div class="gl-flex gl-items-center">
      <gl-icon
        name="check"
        class="gl-mr-3 gl-shrink-0"
        :class="{ 'gl-invisible': !selected }"
        variant="subtle"
      />
      <gl-truncate v-if="truncate" position="middle" :text="text" />
      <template v-else>{{ text }}</template>
    </div>
  </gl-filtered-search-suggestion>
</template>
