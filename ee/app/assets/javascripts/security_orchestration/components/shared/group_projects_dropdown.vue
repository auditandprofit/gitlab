<script>
import { debounce, uniqBy, get } from 'lodash';
import produce from 'immer';
import { __ } from '~/locale';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import BaseItemsDropdown from './base_items_dropdown.vue';

export default {
  i18n: {
    projectDropdownHeader: __('Select projects'),
  },
  name: 'GroupProjectsDropdown',
  components: {
    BaseItemsDropdown,
  },
  apollo: {
    projects: {
      query() {
        return getGroupProjects;
      },
      variables() {
        return {
          ...this.pathVariable,
          search: this.searchTerm,
        };
      },
      update(data) {
        /**
         * It is important to preserve all projects that has benn loaded
         * otherwise after performing backend search and selecting found item
         * selection is overwritten
         */
        const { projects: { nodes = [] } = {} } = data.group || {};
        return uniqBy([...this.projects, ...nodes], 'id');
      },
      result({ data }) {
        this.pageInfo = data?.group?.projects?.pageInfo || {};

        if (this.selectedButNotLoadedProjectIds.length > 0) {
          this.fetchGroupProjectsByIds();
        }
      },
      error() {
        this.$emit('projects-query-error');
      },
    },
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupFullPath: {
      type: String,
      required: true,
    },
    placement: {
      type: String,
      required: false,
      default: 'bottom-start',
    },
    selected: {
      type: [Array, String],
      required: false,
      default: () => [],
    },
    multiple: {
      type: Boolean,
      required: false,
      default: true,
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      pageInfo: {},
      searchTerm: '',
      projects: [],
    };
  },
  computed: {
    projectIds() {
      return this.filteredProjects?.map(({ id }) => id);
    },
    selectedButNotLoadedProjectIds() {
      const selected = this.multiple ? this.selected : [this.selected];
      return selected.filter((id) => !this.projectIds.includes(id));
    },
    filteredProjects() {
      if (this.groupIds.length === 0) {
        return this.projects;
      }

      return this.projects.filter(({ group = {} }) => this.groupIds.includes(group.id));
    },
    items() {
      return this.filteredProjects;
    },
    itemTypeName() {
      return this.isGroup ? __('groups') : __('projects');
    },
    existingFormattedSelectedIds() {
      if (this.multiple) {
        return this.selected.filter((id) => this.projectIds.includes(id));
      }

      return this.selected;
    },
    loading() {
      return this.$apollo.queries.projects.loading;
    },
    searching() {
      return this.loading && this.searchUsed && !this.hasNextPage;
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage;
    },
    listBoxItems() {
      const items = this.items.map(({ id, fullPath, name }) => ({
        text: name,
        value: id,
        fullPath,
      }));

      return searchInItemsProperties({
        items,
        properties: ['text', 'fullPath'],
        searchQuery: this.searchTerm,
      });
    },
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
    pathVariable() {
      return { fullPath: this.groupFullPath };
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    async fetchGroupProjectsByIds() {
      const variables = {
        after: this.pageInfo.endCursor,
        projectIds: this.selectedButNotLoadedProjectIds,
        ...this.pathVariable,
      };

      try {
        const { data } = await this.$apollo.query({
          query: getGroupProjects,
          variables,
        });
        const { projects: { nodes = [] } = {} } = data.group || {};
        this.projects = uniqBy([...this.projects, ...nodes], 'id');
      } catch {
        this.$emit('projects-query-error');
      }
    },
    fetchMoreItems() {
      const variables = {
        after: this.pageInfo.endCursor,
        ...this.pathVariable,
      };

      this.$apollo.queries.projects
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              const getSourceObject = (source) => {
                return get(source, 'group.projects');
              };

              getSourceObject(draftData).nodes = [
                ...getSourceObject(previousResult).nodes,
                ...getSourceObject(draftData).nodes,
              ];
            });
          },
        })
        .catch(() => {
          this.$emit('projects-query-error');
        });
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectItems(selected) {
      const ids = this.multiple ? selected : [selected];
      const selectedItems = this.items.filter(({ id }) => ids.includes(id));
      const payload = this.multiple ? selectedItems : selectedItems[0];
      this.$emit('select', payload);
    },
  },
};
</script>

<template>
  <base-items-dropdown
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :multiple="multiple"
    :loading="loading"
    :header-text="$options.i18n.projectDropdownHeader"
    :items="listBoxItems"
    :infinite-scroll="hasNextPage"
    :searching="searching"
    :selected="existingFormattedSelectedIds"
    :placement="placement"
    :item-type-name="itemTypeName"
    @bottom-reached="fetchMoreItems"
    @search="debouncedSearch"
    @reset="selectItems([])"
    @select="selectItems"
    @select-all="selectItems"
  />
</template>
