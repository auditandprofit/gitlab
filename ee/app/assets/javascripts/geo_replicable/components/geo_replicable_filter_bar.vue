<script>
import { GlSearchBoxByType, GlCollapsibleListbox, GlModalDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import { s__ } from '~/locale';
import { DEFAULT_SEARCH_DELAY, FILTER_STATES, FILTER_OPTIONS, BULK_ACTIONS } from '../constants';

export default {
  name: 'GeoReplicableFilterBar',
  i18n: {
    searchPlaceholder: s__('Geo|Filter by name'),
  },
  components: {
    GlSearchBoxByType,
    GlCollapsibleListbox,
    GeoListBulkActions,
  },
  directives: {
    GlModalDirective,
  },
  computed: {
    ...mapState(['statusFilter', 'searchFilter', 'replicableItems', 'titlePlural']),
    search: {
      get() {
        return this.searchFilter;
      },
      set(val) {
        this.setSearch(val);
        this.fetchReplicableItems();
      },
    },
    dropdownItems() {
      return FILTER_OPTIONS.map((option) => {
        if (option.value === FILTER_STATES.ALL.value) {
          return { ...option, text: `${option.label} ${this.titlePlural}` };
        }

        return { ...option, text: option.label };
      });
    },
    hasReplicableItems() {
      return this.replicableItems.length > 0;
    },
    showBulkActions() {
      return this.hasReplicableItems;
    },
    showSearch() {
      // To be implemented via https://gitlab.com/gitlab-org/gitlab/-/issues/411982
      return false;
    },
  },
  methods: {
    ...mapActions([
      'setStatusFilter',
      'setSearch',
      'fetchReplicableItems',
      'initiateAllReplicableAction',
    ]),
    filterChange(filter) {
      this.setStatusFilter(filter);
      this.fetchReplicableItems();
    },
    onBulkAction(action) {
      this.initiateAllReplicableAction({ action });
    },
  },
  BULK_ACTIONS,
  debounce: DEFAULT_SEARCH_DELAY,
};
</script>

<template>
  <nav class="gl-bg-strong gl-p-5">
    <div class="geo-replicable-filter-grid gl-grid gl-gap-3">
      <div class="gl-flex gl-flex-col gl-items-center sm:gl-flex-row">
        <gl-collapsible-listbox
          class="gl-w-1/2"
          :items="dropdownItems"
          :selected="statusFilter"
          block
          @select="filterChange"
        />
        <gl-search-box-by-type
          v-if="showSearch"
          v-model="search"
          :debounce="$options.debounce"
          class="gl-ml-0 gl-mt-3 gl-w-full sm:gl-ml-3 sm:gl-mt-0"
          :placeholder="$options.i18n.searchPlaceholder"
        />
      </div>
      <geo-list-bulk-actions
        v-if="showBulkActions"
        :bulk-actions="$options.BULK_ACTIONS"
        class="gl-ml-auto"
        @bulkAction="onBulkAction"
      />
    </div>
  </nav>
</template>
