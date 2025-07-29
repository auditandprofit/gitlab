<script>
import { GlPopover, GlLink } from '@gitlab/ui';
import { debounce, get, set, uniqBy } from 'lodash';
import produce from 'immer';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';
import getSppLinkedProjectGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import BaseItemsDropdown from './base_items_dropdown.vue';

export default {
  ERROR_KEY: 'linked-items-query-error',
  SECURITY_POLICY_PROJECT_PATH: helpPagePath(
    'user/application_security/policies/security_policy_projects.md',
  ),
  i18n: {
    groupDropdownHeader: __('Select groups'),
    popoverTitle: s__('SecurityOrchestration|No linked groups'),
    popoverLink: s__('SecurityOrchestration|How do I link a group to the policy?'),
  },
  name: 'ScopedGroupsDropdown',
  components: {
    GlPopover,
    GlLink,
    BaseItemsDropdown,
  },
  apollo: {
    groups: {
      query() {
        return this.designatedAsCsp ? getGroups : getSppLinkedProjectGroups;
      },
      variables() {
        if (this.designatedAsCsp) {
          return {
            search: this.searchTerm,
          };
        }

        return {
          fullPath: this.fullPath,
          includeParentDescendants: this.includeDescendants,
          search: this.searchTerm,
        };
      },
      update(data) {
        const groups = get(data, this.queryDataPath, []);
        const getUniqueItems = (moreItems = []) =>
          uniqBy([...this.items, ...groups, ...moreItems], 'id');

        if (this.designatedAsCsp) {
          this.items = getUniqueItems();
        } else {
          // Descendants only matter when we want to get all groups under parent groups
          const descendants = this.flatMapDescendantGroups(groups);
          this.items = getUniqueItems(descendants);
        }

        this.pageInfo = get(data, this.queryPageInfoPath, {});
        this.$emit('loaded', this.items);
      },
      result() {
        if (this.selectedButNotLoadedGroupIds.length > 0) {
          this.fetchGroupsByIds();
        }
      },
      error() {
        this.$emit(this.$options.ERROR_KEY);
        this.$emit('loaded', this.items);
      },
    },
  },
  inject: ['designatedAsCsp'],
  props: {
    includeDescendants: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      items: [],
      pageInfo: {},
      searchTerm: '',
      // eslint-disable-next-line vue/no-unused-properties -- initialized for Apollo reactivity
      groups: {},
    };
  },
  computed: {
    selectedButNotLoadedGroupIds() {
      return this.selected.filter((id) => !this.itemsIds.includes(id));
    },
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
    dropdownDisabled() {
      return this.disabled || this.showPopover;
    },
    loading() {
      return this.$apollo.queries.groups.loading;
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
    itemsIds() {
      return this.items.map(({ id }) => id);
    },
    existingFormattedSelectedIds() {
      return this.selected.filter((id) => this.itemsIds.includes(id));
    },
    queryDataPath() {
      return this.designatedAsCsp
        ? 'groups.nodes'
        : 'project.securityPolicyProjectLinkedGroups.nodes';
    },
    queryPageInfoPath() {
      return this.designatedAsCsp
        ? 'groups.pageInfo'
        : 'project.securityPolicyProjectLinkedGroups.pageInfo';
    },
    showPopover() {
      return !this.loading && this.items.length === 0;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    flatMapDescendantGroups(groups) {
      return groups.flatMap(({ descendantGroups }) => descendantGroups.nodes);
    },
    async fetchGroupsByIds() {
      const variables = {
        topLevelOnly: false,
        ids: this.selectedButNotLoadedGroupIds,
      };

      try {
        const { data } = await this.$apollo.query({
          query: getGroups,
          variables,
        });

        this.items = uniqBy([...this.items, ...data.groups.nodes], 'id');
      } catch {
        this.$emit(this.$options.ERROR_KEY);
      }
    },
    fetchMoreItems() {
      const variables = {
        after: this.pageInfo.endCursor,
        ...(this.designatedAsCsp ? {} : { fullPath: this.fullPath }),
      };

      this.$apollo.queries.groups
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              const data = [
                ...get(previousResult, this.queryDataPath, []),
                ...get(draftData, this.queryDataPath, []),
              ];
              set(draftData, this.queryDataPath, data);
            });
          },
        })
        .catch(() => {
          this.$emit(this.$options.ERROR_KEY);
        });
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    selectItems(selected) {
      const selectedItems = this.items.filter(({ id }) => selected.includes(id));
      this.$emit('select', selectedItems);
    },
  },
};
</script>

<template>
  <div>
    <gl-popover
      v-if="showPopover"
      boundary="viewport"
      triggers="manual blur"
      target="scoped-groups"
      placement="bottom"
      show-close-button
      :show="true"
    >
      <p>{{ $options.i18n.popoverTitle }}</p>
      <gl-link :href="$options.SECURITY_POLICY_PROJECT_PATH" target="_blank">
        {{ $options.i18n.popoverLink }}
      </gl-link>
    </gl-popover>

    <base-items-dropdown
      id="scoped-groups"
      multiple
      :category="category"
      :variant="variant"
      :disabled="dropdownDisabled"
      :loading="loading"
      :header-text="$options.i18n.groupDropdownHeader"
      :items="listBoxItems"
      :infinite-scroll="hasNextPage"
      :searching="searching"
      :selected="existingFormattedSelectedIds"
      :item-type-name="__('groups')"
      @bottom-reached="fetchMoreItems"
      @search="debouncedSearch"
      @reset="selectItems([])"
      @select="selectItems"
      @select-all="selectItems"
    />
  </div>
</template>
