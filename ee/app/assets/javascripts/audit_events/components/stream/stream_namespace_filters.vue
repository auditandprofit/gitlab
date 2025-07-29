<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import { getTypeFromGraphQLId } from '~/graphql_shared/utils';

import { AUDIT_STREAMS_FILTERING } from '../../constants';
import getNamespaceFiltersQuery from '../../graphql/queries/get_namespace_filters.query.graphql';

export default {
  components: {
    GlCollapsibleListbox,
  },
  inject: ['groupPath'],
  props: {
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      searchTerm: '',
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    filterTargets: {
      query: getNamespaceFiltersQuery,
      variables() {
        return {
          search: this.searchTerm,
          fullPath: this.groupPath,
        };
      },
      update(data) {
        return {
          groups: data.group.descendantGroups.nodes,
          projects: data.group.projects.nodes,
        };
      },
    },
  },
  computed: {
    selectedEntry() {
      if (!this.filterTargets) {
        return [];
      }

      return [...this.filterTargets.groups, ...this.filterTargets.projects].find(
        (n) => n.fullPath === this.value.namespace,
      );
    },

    selectedId() {
      return this.selectedEntry?.id;
    },

    options() {
      const result = [];
      if (this.filterTargets?.groups.length > 0) {
        result.push({
          text: __('Groups'),
          options: this.filterTargets.groups.map((g) => ({
            text: g.name,
            value: g.id,
          })),
        });
      }
      if (this.filterTargets?.projects.length > 0) {
        result.push({
          text: __('Projects'),
          options: this.filterTargets.projects.map((p) => ({
            text: p.name,
            value: p.id,
          })),
        });
      }
      return result;
    },
    toggleText() {
      if (!this.value?.namespace) {
        return this.$options.i18n.SELECT_NAMESPACE;
      }

      return this.selectedEntry?.name || this.value.namespace;
    },
  },
  methods: {
    updateSearchTerm(searchTerm) {
      this.searchTerm = searchTerm.toLowerCase();
    },
    selectOption($event) {
      const type = getTypeFromGraphQLId($event);

      if (type === 'Group') {
        const group = this.filterTargets?.groups.find((g) => g.id === $event);
        this.$emit('input', { namespace: group.fullPath, type: 'group' });
        return;
      }

      const project = this.filterTargets?.projects.find((p) => p.id === $event);
      this.$emit('input', { namespace: project.fullPath, type: 'project' });
    },
    resetOptions() {
      this.$emit('input', { namespace: '', type: 'project' });
    },
  },
  i18n: AUDIT_STREAMS_FILTERING,
};
</script>

<template>
  <gl-collapsible-listbox
    id="audit-event-type-filter"
    :items="options"
    :selected="selectedId"
    :header-text="$options.i18n.SELECT_NAMESPACE"
    :show-select-all-button-label="$options.i18n.SELECT_ALL"
    :reset-button-label="$options.i18n.UNSELECT_ALL"
    :no-results-text="$options.i18n.NO_RESULT_TEXT"
    :search-placeholder="$options.i18n.SEARCH_PLACEHOLDER"
    searchable
    :searching="$apollo.queries.filterTargets.loading"
    toggle-class="gl-max-w-full"
    :toggle-text="toggleText"
    class="gl-max-w-full"
    @select="selectOption"
    @reset="resetOptions"
    @search="updateSearchTerm"
  />
</template>
