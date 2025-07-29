<script>
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { queryToObject } from '~/lib/utils/url_utility';

export default {
  name: 'InventoryDashboardFilteredSearchBar',
  components: {
    FilteredSearch,
  },
  props: {
    initialFilters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    namespace: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      initialSortBy: 'updated_at_desc',
      filterParams: {},
    };
  },
  computed: {
    searchTokens() {
      return [];
    },
    initialFilterValue() {
      if (this.initialFilters.search) {
        return [this.initialFilters.search];
      }
      const searchParam = queryToObject(window.location.search).search;
      return searchParam ? [searchParam] : [];
    },
  },
  methods: {
    onFilter(filters = []) {
      const filterParams = {};
      const plainText = [];

      filters.forEach((filter) => {
        if (!filter.value.data) return;

        if (filter.type === FILTERED_SEARCH_TERM) {
          plainText.push(filter.value.data);
        }
      });

      if (plainText.length) {
        filterParams.search = plainText.join(' ');
      }

      this.filterParams = { ...filterParams };
      this.$emit('filterSubgroupsAndProjects', this.filterParams);
    },
  },
};
</script>

<template>
  <filtered-search
    class="gl-pr-3"
    v-bind="$attrs"
    :namespace="namespace"
    :initial-filter-value="initialFilterValue"
    :tokens="searchTokens"
    :initial-sort-by="initialSortBy"
    :search-input-placeholder="s__('SecurityInventoryFilter|Search projects…')"
    :search-text-option-label="s__('SecurityInventoryFilter|Search for project name')"
    terms-as-tokens
    @onFilter="onFilter"
  />
</template>
