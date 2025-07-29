<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { GlKeysetPagination } from '@gitlab/ui';
import TablePagination from '~/vue_shared/components/pagination/table_pagination.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import DependenciesTable from './dependencies_table.vue';

export default {
  name: 'PaginatedDependenciesTable',
  components: {
    DependenciesTable,
    GlKeysetPagination,
    TablePagination,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['vulnerabilitiesEndpoint'],
  computed: {
    ...mapState({
      shouldShowPagination(state) {
        const { isLoading, errorLoading, pageInfo } = state;
        return Boolean(!isLoading && !errorLoading && !this.showKeysetPagination && pageInfo);
      },
      showKeysetPagination(state) {
        const { isLoading, errorLoading, pageInfo } = state;

        if (isLoading || errorLoading || !pageInfo) return false;

        return pageInfo.hasNextPage || pageInfo.hasPreviousPage;
      },
    }),
    ...mapState([
      'dependencies',
      'vulnerabilityItemsLoading',
      'vulnerabilityInfo',
      'isLoading',
      'pageInfo',
    ]),
  },
  methods: {
    ...mapActions({
      fetchPage(dispatch, page) {
        return dispatch('fetchDependencies', { page });
      },
      fetchCursorPage(dispatch, cursor) {
        if (this.glFeatures.projectDependenciesGraphql) {
          return dispatch('fetchDependenciesViaGraphQL', { cursor });
        }

        return dispatch('fetchDependencies', { cursor });
      },
      fetchVulnerabilities(dispatch, item) {
        if (this.glFeatures.projectDependenciesGraphql) {
          return dispatch('fetchVulnerabilitiesViaGraphQL', { item });
        }

        return dispatch('fetchVulnerabilities', {
          item,
          vulnerabilitiesEndpoint: this.vulnerabilitiesEndpoint,
        });
      },
    }),
  },
};
</script>

<template>
  <div>
    <dependencies-table
      :dependencies="dependencies"
      :vulnerability-info="vulnerabilityInfo"
      :vulnerability-items-loading="vulnerabilityItemsLoading"
      :is-loading="isLoading"
      @row-click="fetchVulnerabilities"
    />

    <table-pagination
      v-if="shouldShowPagination"
      :change="fetchPage"
      :page-info="pageInfo"
      align="center"
    />
    <div v-if="showKeysetPagination" class="gl-mt-5 gl-text-center">
      <gl-keyset-pagination v-bind="pageInfo" @prev="fetchCursorPage" @next="fetchCursorPage" />
    </div>
  </div>
</template>
