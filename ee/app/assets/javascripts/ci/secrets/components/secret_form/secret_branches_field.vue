<script>
import { GlCollapsibleListbox, GlDropdownItem, GlDropdownDivider } from '@gitlab/ui';
import { debounce, uniq } from 'lodash';
import { createAlert } from '~/alert';
import { __, sprintf } from '~/locale';
import { BRANCH_QUERY_LIMIT } from '../../constants';
import getProjectBranches from '../../graphql/queries/get_project_branches.query.graphql';

export default {
  name: 'SecretBranchesField',
  components: {
    GlCollapsibleListbox,
    GlDropdownItem,
    GlDropdownDivider,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    selectedBranch: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      branches: [],
      searchTerm: '',
    };
  },
  apollo: {
    branches: {
      query: getProjectBranches,
      variables() {
        return {
          limit: BRANCH_QUERY_LIMIT,
          projectPath: this.fullPath,
          searchPattern: `*${this.searchTerm}*`,
        };
      },
      update({ project: { repository = {} } } = {}) {
        return repository.branchNames || [];
      },
      error() {
        createAlert({ message: __('An error occurred while fetching branches.') });
      },
    },
  },
  computed: {
    branchesList() {
      let list = this.branches;
      const showSelectedBranch = !this.searchTerm || this.selectedBranch.includes(this.searchTerm);

      // selected branch can be a custom wildcard, which may not show up in search
      if (this.selectedBranch.length > 0 && showSelectedBranch) {
        list = uniq([this.selectedBranch, ...list]);
      }

      return list.map((branch) => ({
        value: branch,
        text: branch,
      }));
    },
    createWildcardButtonText() {
      return sprintf(__('Create wildcard: %{searchTerm}'), { searchTerm: this.searchTerm });
    },
    isLoading() {
      return this.$apollo.queries.branches?.loading;
    },
    showCreateWildcardButton() {
      return this.searchTerm?.includes('*') && !this.branches.includes(this.searchTerm);
    },
    toggleText() {
      return this.selectedBranch.length > 0
        ? this.selectedBranch
        : __('Select branch or create wildcard');
    },
  },
  methods: {
    debouncedSearch: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm.trim();
      this.$apollo.queries.branches.refetch();
    }, 500),
    selectBranch(branch) {
      this.$emit('select-branch', branch);
    },
  },
  BRANCH_QUERY_LIMIT,
  i18n: {
    searchQueryNote: __(
      'Enter a search query to find more branches, or use * to create a wildcard.',
    ),
  },
};
</script>
<template>
  <gl-collapsible-listbox
    block
    searchable
    :selected="selectedBranch"
    :items="branchesList"
    :loading="isLoading"
    :searching="isLoading"
    :toggle-text="toggleText"
    @search="debouncedSearch"
    @select="selectBranch"
  >
    <template #footer>
      <gl-dropdown-divider v-if="!isLoading" />
      <gl-dropdown-item class="gl-list-none" disabled data-testid="search-query-note">
        {{ $options.i18n.searchQueryNote }}
      </gl-dropdown-item>
      <gl-dropdown-item
        v-if="showCreateWildcardButton"
        class="gl-list-none"
        data-testid="create-wildcard-button"
        @click="selectBranch(searchTerm)"
      >
        {{ createWildcardButtonText }}
      </gl-dropdown-item>
    </template>
  </gl-collapsible-listbox>
</template>
