<script>
import { GlButton } from '@gitlab/ui';
import { debounce } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import {
  getLocationHash,
  queryToObject,
  setUrlParams,
  updateHistory,
} from '~/lib/utils/url_utility';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { SIDEBAR_VISIBLE_STORAGE_KEY } from '../constants';
import SubgroupsAndProjectsQuery from '../graphql/subgroups_and_projects.query.graphql';
import { getData, getPageInfo } from '../graphql/helper';
import SubgroupSidebar from './sidebar/subgroup_sidebar.vue';
import EmptyState from './empty_state.vue';
import SecurityInventoryTable from './security_inventory_table.vue';
import InventoryDashboardFilteredSearchBar from './inventory_dashboard_filtered_search_bar.vue';

const PAGE_SIZE = 20;

export default {
  components: {
    SubgroupSidebar,
    LocalStorageSync,
    RecursiveBreadcrumbs: () => import('./recursive_breadcrumbs.vue'),
    GlButton,
    EmptyState,
    SecurityInventoryTable,
    InventoryDashboardFilteredSearchBar,
  },
  inject: ['groupFullPath', 'newProjectPath'],
  i18n: {
    errorFetchingChildren: s__(
      'SecurityInventory|An error occurred while fetching subgroups and projects. Please try again.',
    ),
    loadMore: s__('SecurityInventory|Load more'),
  },
  data() {
    return {
      activeFullPath: this.groupFullPath,
      sidebarVisible: true,
      filters: {
        search: this.getSearchParams(),
      },
      // displayItems is the combined list of Project and Subgroups to be shown in the UI.
      displayItems: [],
      subgroupItems: [],
      projectItems: [],
      subgroupsPageInfo: {
        hasNextPage: false,
        endCursor: null,
      },
      projectsPageInfo: {
        hasNextPage: false,
        endCursor: null,
      },
      isLoadingMore: false,
      projectsInitialized: false,
    };
  },
  apollo: {
    subgroupItems: {
      query: SubgroupsAndProjectsQuery,
      variables() {
        return {
          fullPath: this.activeFullPath,
          search: this.filters.search || '',
          hasSearch: this.hasSearch,
          subgroupsFirst: PAGE_SIZE,
          subgroupsAfter: null,
          projectsFirst: PAGE_SIZE,
          projectsAfter: null,
        };
      },
      update(data) {
        const groupData = getData(data, 'group');
        if (!groupData) return [];

        return getData(groupData, 'descendantGroups.nodes', []);
      },
      result({ data }) {
        const groupData = getData(data, 'group');
        if (!groupData) return;

        this.subgroupsPageInfo = getPageInfo(groupData, 'descendantGroups.pageInfo');
        this.projectsPageInfo = getPageInfo(groupData, 'projects.pageInfo');

        const subgroups = getData(groupData, 'descendantGroups.nodes', []);
        this.projectItems = getData(groupData, 'projects.nodes', []);
        this.projectsInitialized = true;

        // Initially, populate items with only subgroups
        this.displayItems = [...subgroups];

        // Once all subgroups are loaded, display both subgroups and projects
        if (!this.hasMoreSubgroups) {
          this.displayItems = [...subgroups, ...this.projectItems];
        }
      },
      error(error) {
        this.handleError(error);
      },
    },
  },
  computed: {
    hasMoreSubgroups() {
      return this.subgroupsPageInfo?.hasNextPage;
    },
    hasMoreProjects() {
      return this.projectsPageInfo?.hasNextPage;
    },
    isLoading() {
      return this.$apollo.queries.subgroupItems.loading && !this.isLoadingMore;
    },
    hasSearch() {
      return Boolean(this.filters.search);
    },
    hasChildren() {
      return this.displayItems.length > 0;
    },
    showLoadMoreButton() {
      return this.hasMoreSubgroups || this.hasMoreProjects;
    },
    showEmptyState() {
      return !this.isLoading && !this.hasChildren;
    },
  },
  created() {
    this.debouncedFilter = debounce(this.performFilter, 50);
    this.initializeFromUrl();
    window.addEventListener('hashchange', this.handleLocationHashChange);
  },
  beforeDestroy() {
    window.removeEventListener('hashchange', this.handleLocationHashChange);
  },
  methods: {
    handleError(error) {
      createAlert({
        message: this.$options.i18n.errorFetchingChildren,
        error,
        captureError: true,
      });
      Sentry.captureException(error);
    },
    getSearchParams() {
      return queryToObject(window.location.search).search;
    },
    initializeFromUrl() {
      this.handleLocationHashChange();
      this.filters.search = this.getSearchParams();
    },
    handleLocationHashChange() {
      let hash = getLocationHash();
      if (!hash) {
        hash = this.groupFullPath;
      }
      if (this.activeFullPath !== hash) {
        this.activeFullPath = hash;
        this.resetData();
      }
    },
    resetData() {
      this.displayItems = [];
      this.subgroupItems = [];
      this.projectItems = [];
      this.subgroupsPageInfo = {
        hasNextPage: false,
        endCursor: null,
      };
      this.projectsPageInfo = {
        hasNextPage: false,
        endCursor: null,
      };
      this.isLoadingMore = false;
      this.projectsInitialized = false;
    },
    async loadMore() {
      if (this.isLoadingMore) return;
      this.isLoadingMore = true;

      try {
        if (this.hasMoreSubgroups) {
          await this.loadMoreSubgroups();
        } else {
          await this.loadMoreProjects();
        }
      } catch (error) {
        this.handleError(error);
      } finally {
        this.isLoadingMore = false;
      }
    },
    /**
     * Abstracts the GraphQL query for fetching subgroups and projects
     * @param {Object} options - Query options
     * @param {Number} options.subgroupsFirst - Number of subgroups to fetch
     * @param {String} options.subgroupsAfter - Cursor for subgroups pagination
     * @param {Number} options.projectsFirst - Number of projects to fetch
     * @param {String} options.projectsAfter - Cursor for projects pagination
     * @returns {Promise} Apollo query promise
     */
    async fetchSubgroupsAndProjects(options = {}) {
      const {
        subgroupsFirst = 0,
        subgroupsAfter = null,
        projectsFirst = 0,
        projectsAfter = null,
      } = options;

      return this.$apollo.query({
        query: SubgroupsAndProjectsQuery,
        variables: {
          fullPath: this.activeFullPath,
          search: this.filters.search || '',
          hasSearch: this.hasSearch,
          subgroupsFirst,
          subgroupsAfter,
          projectsFirst,
          projectsAfter,
        },
      });
    },
    async loadMoreSubgroups() {
      const { data } = await this.fetchSubgroupsAndProjects({
        subgroupsFirst: PAGE_SIZE,
        subgroupsAfter: this.subgroupsPageInfo.endCursor,
      });

      const groupData = getData(data, 'group');
      if (!groupData) return;

      const newSubgroups = getData(groupData, 'descendantGroups.nodes', []);
      this.subgroupsPageInfo = getPageInfo(groupData, 'descendantGroups.pageInfo');
      this.subgroupItems = [...this.subgroupItems, ...newSubgroups];

      if (!this.hasMoreSubgroups) {
        this.displayItems = [...this.subgroupItems, ...this.projectItems];
      } else {
        this.displayItems = [...this.subgroupItems];
      }
    },
    async loadMoreProjects() {
      const { data } = await this.fetchSubgroupsAndProjects({
        projectsFirst: PAGE_SIZE,
        projectsAfter: this.projectsPageInfo.endCursor,
      });

      const groupData = getData(data, 'group');
      if (!groupData) return;

      const newProjects = getData(groupData, 'projects.nodes', []);
      this.projectsPageInfo = getPageInfo(groupData, 'projects.pageInfo');
      this.projectItems = [...this.projectItems, ...newProjects];

      this.displayItems = [...this.subgroupItems, ...this.projectItems];
    },
    toggleSidebar(value = !this.sidebarVisible) {
      this.sidebarVisible = value;
    },
    filterSubgroupsAndProjects(filters) {
      this.filters = filters;
      this.debouncedFilter(filters);
    },
    performFilter(filters) {
      const currentHash = getLocationHash();
      const newUrl = setUrlParams(filters, window.location.href, true);
      const urlWithHashPreserved = newUrl.split('#')[0] + (currentHash ? `#${currentHash}` : '');
      updateHistory({
        url: urlWithHashPreserved,
      });
    },
  },
  SIDEBAR_VISIBLE_STORAGE_KEY,
};
</script>

<template>
  <div class="-gl-mb-10 gl-mt-5">
    <div
      class="gl-flex gl-w-full gl-border-b-1 gl-border-t-1 gl-border-gray-100 gl-bg-subtle gl-border-b-solid gl-border-t-solid"
    >
      <gl-button
        icon="sidebar"
        icon-only
        class="gl-m-3"
        :aria-label="sidebarVisible ? __('Collapse sidebar') : __('Expand sidebar')"
        @click="toggleSidebar()"
      />
      <inventory-dashboard-filtered-search-bar
        class="gl-flex-auto gl-items-center"
        :initial-filters="filters"
        :namespace="activeFullPath"
        @filterSubgroupsAndProjects="filterSubgroupsAndProjects"
      />
    </div>
    <local-storage-sync
      v-model="sidebarVisible"
      :storage-key="$options.SIDEBAR_VISIBLE_STORAGE_KEY"
      @input="toggleSidebar"
    />
    <div class="gl-flex">
      <subgroup-sidebar v-if="sidebarVisible" :active-full-path="activeFullPath" />
      <div class="gl-w-auto gl-grow" :class="{ 'gl-pl-5': sidebarVisible }">
        <recursive-breadcrumbs :group-full-path="groupFullPath" :current-path="activeFullPath" />
        <empty-state v-if="showEmptyState" />
        <security-inventory-table
          v-else
          :items="displayItems"
          :is-loading="isLoading"
          :has-search="hasSearch"
        />
        <div v-if="showLoadMoreButton" class="gl-mt-5 gl-flex gl-justify-center">
          <gl-button data-testid="load-more-button" :loading="isLoadingMore" @click="loadMore">
            {{ $options.i18n.loadMore }}
          </gl-button>
        </div>
      </div>
    </div>
  </div>
</template>
