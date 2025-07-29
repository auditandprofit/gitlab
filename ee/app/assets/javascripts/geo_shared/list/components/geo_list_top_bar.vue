<script>
import { __ } from '~/locale';
import GeoListFilteredSearchBar from './geo_list_filtered_search_bar.vue';
import GeoListBulkActions from './geo_list_bulk_actions.vue';

export default {
  components: {
    GeoListFilteredSearchBar,
    GeoListBulkActions,
  },
  props: {
    listboxHeaderText: {
      type: String,
      required: false,
      default: __('Select item'),
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
    showActions: {
      type: Boolean,
      required: false,
      default: false,
    },
    bulkActions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  methods: {
    handleListboxChange(val) {
      this.$emit('listboxChange', val);
    },
    handleSearch(val) {
      this.$emit('search', val);
    },
    handleBulkAction(action) {
      this.$emit('bulkAction', action);
    },
  },
};
</script>

<template>
  <div>
    <geo-list-filtered-search-bar
      :listbox-header-text="listboxHeaderText"
      :active-listbox-item="activeListboxItem"
      :active-filtered-search-filters="activeFilteredSearchFilters"
      @listboxChange="handleListboxChange"
      @search="handleSearch"
    />
    <geo-list-bulk-actions
      v-if="showActions"
      :bulk-actions="bulkActions"
      class="gl-my-5 gl-flex gl-justify-end"
      @bulkAction="handleBulkAction"
    />
  </div>
</template>
