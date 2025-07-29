<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import GeoListFilteredSearch from './geo_list_filtered_search.vue';

export default {
  components: {
    GlCollapsibleListbox,
    GeoListFilteredSearch,
  },
  inject: {
    listboxItems: {
      type: Array,
      default: [],
    },
  },
  props: {
    listboxHeaderText: {
      type: String,
      required: true,
    },
    activeListboxItem: {
      type: String,
      required: true,
    },
    activeFilteredSearchFilters: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      listboxSearch: '',
    };
  },
  computed: {
    filteredListboxItems() {
      return this.listboxItems.filter(
        (item) =>
          item.text.toLowerCase().includes(this.listboxSearch.toLowerCase()) ||
          item.value === this.activeListboxItem,
      );
    },
    listboxItem: {
      get() {
        return this.activeListboxItem;
      },
      set(val) {
        this.$emit('listboxChange', val);
      },
    },
  },
  methods: {
    handleListboxSearch(search) {
      this.listboxSearch = search;
    },
    handleSearch(val) {
      this.$emit('search', val);
    },
  },
};
</script>

<template>
  <div class="row-content-block">
    <div class="gl-flex gl-grow gl-flex-col gl-border-t-0 sm:gl-flex sm:gl-flex-row sm:gl-gap-3">
      <label id="listbox-select-label" class="gl-sr-only">{{ listboxHeaderText }}</label>
      <gl-collapsible-listbox
        v-model="listboxItem"
        :items="filteredListboxItems"
        :header-text="listboxHeaderText"
        searchable
        toggle-aria-labelled-by="listbox-select-label"
        class="gl-mb-4 sm:gl-mb-0"
        @search="handleListboxSearch"
      />
      <div class="flex-grow-1 gl-flex">
        <geo-list-filtered-search
          :active-filters="activeFilteredSearchFilters"
          @search="handleSearch"
        />
      </div>
    </div>
  </div>
</template>
