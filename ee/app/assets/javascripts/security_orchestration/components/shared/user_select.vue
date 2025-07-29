<script>
import { uniqBy } from 'lodash';
import { GlAvatarLabeled, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import searchProjectMembers from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import searchGroupMembers from '~/graphql_shared/queries/group_users_search.query.graphql';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { isProject } from 'ee/security_orchestration/components/utils';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';

const createUserObject = (user) => ({
  ...user,
  text: user.name,
  username: `@${user.username}`,
  value: user.value || user.id,
});

export default {
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    state: {
      type: Boolean,
      required: false,
      default: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedNames: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  apollo: {
    users: {
      query() {
        return isProject(this.namespaceType) ? searchProjectMembers : searchGroupMembers;
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          search: this.search,
        };
      },
      update(data) {
        const nodes = isProject(this.namespaceType)
          ? data?.project?.projectMembers?.nodes
          : data?.workspace?.users?.nodes;

        const users = (nodes || [])
          .filter(({ user }) => user)
          .map(({ user }) => createUserObject(user));
        const accumulatedUsers = [...this.users, ...users];

        return uniqBy(accumulatedUsers, 'id');
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      error() {
        this.$emit('error');
      },
    },
  },
  data() {
    return {
      search: '',
      users: [],
    };
  },
  computed: {
    listBoxItems() {
      return searchInItemsProperties({
        items: this.users,
        properties: ['text', 'username'],
        searchQuery: this.search,
      });
    },
    userItems() {
      return this.users.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    selectedGraphQlIds() {
      const removeAtSymbol = (username = '') =>
        username.startsWith('@') ? username.substring(1) : username;

      const getUsersByNames = (names) => {
        const normalizedNames = names.map(removeAtSymbol);
        return this.users
          .filter(({ username }) => normalizedNames.includes(removeAtSymbol(username)))
          .map(({ value }) => value);
      };

      const getGraphQLIds = (ids) => ids.map((id) => convertToGraphQLId(TYPENAME_USER, id));

      if (this.selectedNames.length === 0) {
        return getGraphQLIds(this.selected);
      }

      const usersByNames = getUsersByNames(this.selectedNames);

      if (this.selected.length === 0) {
        return usersByNames;
      }

      return [...usersByNames, ...getGraphQLIds(this.selected)];
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedGraphQlIds,
        items: this.userItems,
        itemTypeName: __('users'),
        useAllSelected: false,
      });
    },
    hasSelectedNames() {
      return this.selectedGraphQlIds.length > 0 && this.selectedNames.length > 0;
    },
  },
  updated() {
    /**
     * Edge case when instead of user ids
     * Policy has user names it would be
     * replaced with user ids by emitting
     * change event
     */
    if (this.hasSelectedNames) {
      this.selectUsers(this.selectedGraphQlIds);
    }
  },
  methods: {
    setSearch(value) {
      this.search = value?.trim();
    },
    selectUsers(userIds) {
      this.$emit('select-items', {
        user_approvers_ids: userIds.map((id) => getIdFromGraphQLId(id)),
      });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="listBoxItems"
    :disabled="disabled"
    block
    searchable
    is-check-centered
    multiple
    :header-text="__('Users')"
    :reset-button-label="__('Clear all')"
    :toggle-class="[{ '!gl-shadow-inner-1-red-500': !state }]"
    :searching="$apollo.loading"
    :loading="$apollo.loading"
    :selected="selectedGraphQlIds"
    :toggle-text="toggleText"
    @reset="selectUsers([])"
    @search="setSearch"
    @select="selectUsers"
  >
    <template #list-item="{ item }">
      <gl-avatar-labeled
        shape="circle"
        :size="32"
        :src="item.avatarUrl"
        :label="item.text"
        :sub-label="item.username"
      />
    </template>
  </gl-collapsible-listbox>
</template>
