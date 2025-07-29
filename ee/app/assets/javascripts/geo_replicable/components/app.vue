<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { sprintf, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { visitUrl, pathSegments, queryToObject, setUrlParams } from '~/lib/utils/url_utility';
import {
  isValidFilter,
  getReplicationStatusFilter,
  getReplicableTypeFilter,
  processFilters,
} from '../filters';
import {
  REPLICATION_STATUS_STATES_ARRAY,
  TOKEN_TYPES,
  BULK_ACTIONS,
  GEO_TROUBLESHOOTING_LINK,
} from '../constants';
import GeoReplicable from './geo_replicable.vue';
import GeoReplicableFilterBar from './geo_replicable_filter_bar.vue';
import GeoFeedbackBanner from './geo_feedback_banner.vue';

export default {
  name: 'GeoReplicableApp',
  components: {
    GeoReplicableFilterBar,
    GeoListTopBar,
    GeoReplicable,
    GeoFeedbackBanner,
    GeoList,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    itemTitle: {
      default: '',
    },
  },
  data() {
    return {
      activeFilters: [],
    };
  },
  computed: {
    ...mapState(['isLoading', 'replicableItems']),
    ...mapGetters(['hasFilters']),
    hasReplicableItems() {
      return this.replicableItems.length > 0;
    },
    activeReplicableType() {
      const activeFilter = this.activeFilters.find(
        ({ type }) => type === TOKEN_TYPES.REPLICABLE_TYPE,
      );

      return activeFilter?.value;
    },
    activeFilteredSearchFilters() {
      return this.activeFilters.filter(({ type }) => type !== TOKEN_TYPES.REPLICABLE_TYPE);
    },
    emptyStateHasFilters() {
      return this.glFeatures.geoReplicablesFilteredListView
        ? Boolean(this.activeFilteredSearchFilters.length)
        : this.hasFilters;
    },
    emptyState() {
      return {
        title: sprintf(s__('Geo|There are no %{itemTitle} to show'), { itemTitle: this.itemTitle }),
        description: s__(
          'Geo|No %{itemTitle} were found. If you believe this may be an error, please refer to the %{linkStart}Geo Troubleshooting%{linkEnd} documentation for more information.',
        ),
        itemTitle: this.itemTitle,
        helpLink: GEO_TROUBLESHOOTING_LINK,
        hasFilters: this.emptyStateHasFilters,
      };
    },
  },
  created() {
    if (this.glFeatures.geoReplicablesFilteredListView) {
      this.getFiltersFromQuery();
    }

    this.fetchReplicableItems();
  },
  methods: {
    ...mapActions(['fetchReplicableItems', 'setStatusFilter', 'initiateAllReplicableAction']),
    getFiltersFromQuery() {
      const filters = [];
      const url = new URL(window.location.href);
      const segments = pathSegments(url);
      const { replication_status: replicationStatus } = queryToObject(window.location.search || '');

      if (isValidFilter(replicationStatus, REPLICATION_STATUS_STATES_ARRAY)) {
        filters.push(getReplicationStatusFilter(replicationStatus));
        this.setStatusFilter(replicationStatus);
      }

      this.activeFilters = [getReplicableTypeFilter(segments.pop()), ...filters];
    },
    handleListboxChange(val) {
      this.handleSearch([getReplicableTypeFilter(val), ...this.activeFilteredSearchFilters]);
    },
    handleSearch(filters) {
      const { query, url } = processFilters(filters);

      visitUrl(setUrlParams(query, url.href, true));
    },
    handleBulkAction(action) {
      this.initiateAllReplicableAction({ action });
    },
  },
  BULK_ACTIONS,
};
</script>

<template>
  <article class="geo-replicable-container">
    <geo-feedback-banner />
    <geo-replicable-filter-bar v-if="!glFeatures.geoReplicablesFilteredListView" />
    <geo-list-top-bar
      v-else
      :listbox-header-text="s__('Geo|Select replicable type')"
      :active-listbox-item="activeReplicableType"
      :active-filtered-search-filters="activeFilteredSearchFilters"
      :show-actions="hasReplicableItems"
      :bulk-actions="$options.BULK_ACTIONS"
      @listboxChange="handleListboxChange"
      @search="handleSearch"
      @bulkAction="handleBulkAction"
    />

    <geo-list :is-loading="isLoading" :has-items="hasReplicableItems" :empty-state="emptyState">
      <geo-replicable />
    </geo-list>
  </article>
</template>
