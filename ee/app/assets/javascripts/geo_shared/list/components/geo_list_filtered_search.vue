<script>
import { GlFilteredSearch } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  i18n: {
    searchPlaceholder: __('Search or filter results…'),
  },
  components: {
    GlFilteredSearch,
  },
  inject: {
    filteredSearchTokens: {
      type: Array,
      default: [],
    },
  },
  props: {
    activeFilters: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  methods: {
    handleSubmit(val) {
      this.$emit('search', val);
    },
  },
};
</script>

<template>
  <gl-filtered-search
    :value="activeFilters"
    :available-tokens="filteredSearchTokens"
    terms-as-tokens
    :placeholder="$options.i18n.searchPlaceholder"
    @submit="handleSubmit"
  />
</template>
