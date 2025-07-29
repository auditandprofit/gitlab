<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import { groupByIterationCadences } from 'ee/iterations/utils';
import { STATUS_OPEN } from '~/issues/constants';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { __ } from '~/locale';
import { iterationSelectTextMap } from '../../constants';
import groupIterationsQuery from '../../queries/group_iterations.query.graphql';

const NO_ITEMS_ID = 'NO_ITEMS_ID';

export default {
  noIteration: { text: iterationSelectTextMap.noIteration, id: NO_ITEMS_ID },
  components: {
    GlCollapsibleListbox,
    IterationTitle,
  },
  apollo: {
    iterations: {
      query: groupIterationsQuery,
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      variables() {
        const search = this.searchTerm ? `"${this.searchTerm}"` : '';

        return {
          fullPath: this.fullPath,
          title: search,
          state: STATUS_OPEN,
        };
      },
      update(data) {
        return data.workspace?.attributes?.nodes || [];
      },
      skip() {
        return !this.shouldFetch;
      },
    },
  },
  inject: ['fullPath'],
  data() {
    return {
      searchTerm: '',
      iterations: [],
      currentIteration: null,
      shouldFetch: false,
    };
  },
  computed: {
    currentIterationId() {
      return this.currentIteration?.id;
    },
    iterationCadences() {
      return groupByIterationCadences(this.iterations);
    },
    iterationCadencesListBoxItems() {
      const groups = this.iterationCadences.map((cadence) => ({
        text: cadence.title,
        options: cadence.iterations.map(({ id, period, title }) => ({
          value: id,
          text: period,
          title,
        })),
      }));

      return [
        {
          text: this.$options.noIteration.text,
          options: [
            {
              text: this.$options.noIteration.text,
              value: this.$options.noIteration.id,
            },
          ],
        },
        ...groups,
      ];
    },
    dropdownSelectedText() {
      return this.currentIteration?.period || __('Select iteration');
    },
    dropdownHeaderText() {
      return __('Select Iteration');
    },
  },
  created() {
    this.handleSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.handleSearch.cancel();
  },
  methods: {
    setSearchTerm(val = '') {
      this.searchTerm = val?.trim();
    },
    onClick(iterationId) {
      this.currentIteration =
        this.iterationCadences
          .flatMap((cadence) => cadence.iterations)
          ?.find(({ id }) => id === iterationId) || this.$options.noIteration;

      this.$emit('onIterationSelect', this.currentIteration);
    },
    onDropdownShow() {
      this.shouldFetch = true;
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    is-check-centered
    searchable
    toggle-class="gl-w-full"
    :header-text="dropdownHeaderText"
    :items="iterationCadencesListBoxItems"
    :loading="$apollo.queries.iterations.loading"
    :searching="$apollo.queries.iterations.loading"
    :selected="currentIterationId"
    :toggle-text="dropdownSelectedText"
    @shown="onDropdownShow"
    @search="handleSearch"
    @select="onClick"
  >
    <template #list-item="{ item }">
      {{ item.text }}
      <iteration-title v-if="item.title" :title="item.title" />
    </template>
  </gl-collapsible-listbox>
</template>
