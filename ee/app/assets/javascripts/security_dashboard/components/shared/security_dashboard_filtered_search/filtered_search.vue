<script>
import { GlFilteredSearch } from '@gitlab/ui';
import { isEqual } from 'lodash';

export default {
  components: {
    GlFilteredSearch,
  },
  props: {
    tokens: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      filters: {},
      value: [],
    };
  },
  methods: {
    handleInput(inputValues) {
      const isFilterToken = ({ type }) => this.tokens.some((token) => token.type === type);
      const filterTokens = inputValues.filter(isFilterToken);

      if (filterTokens.length === 0) {
        this.clear();
        return;
      }

      // When the user clicks on the selected value (placeholder), the filtered search
      // empties the selection handler and sends a null value
      // We don't want to cause a new API call when this happens. Instead
      // we want to wait until user either destroys the token or selects a new token.
      if (filterTokens.some(({ value }) => !value.data)) {
        return;
      }

      const newFilters = {};
      filterTokens.forEach(({ type, value }) => {
        newFilters[type] = value.data;
      });

      if (isEqual(this.filters, newFilters)) {
        return;
      }

      this.filters = newFilters;
      this.$emit('filters-changed', newFilters);
    },
    clear() {
      this.$emit('filters-changed', {});
    },
  },
};
</script>
<template>
  <gl-filtered-search
    :placeholder="s__('SecurityReports|Filter results...')"
    :available-tokens="tokens"
    :value="value"
    @input="handleInput"
    @clear="clear"
  />
</template>
