<script>
import { GlTooltipDirective, GlLoadingIcon, GlAlert } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import ThroughputTable from 'ee/analytics/analytics_dashboards/components/visualizations/merge_requests/throughput_table.vue';
import { dateFormats } from '~/analytics/shared/constants';
import dateFormat from '~/lib/dateformat';
import { filterToQueryObject } from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import { THROUGHPUT_TABLE_STRINGS, PER_PAGE } from '../constants';
import throughputTableQuery from '../graphql/queries/throughput_table.query.graphql';

const initialPaginationState = {
  prevPageCursor: '',
  nextPageCursor: '',
  firstPageSize: PER_PAGE,
  lastPageSize: null,
};

export default {
  name: 'ThroughputTableProvider',
  components: {
    GlLoadingIcon,
    GlAlert,
    ThroughputTable,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['fullPath'],
  props: {
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
  },
  data() {
    return {
      throughputTableData: {},
      pagination: initialPaginationState,
      hasError: false,
    };
  },
  apollo: {
    throughputTableData: {
      query: throughputTableQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          startDate: dateFormat(this.startDate, dateFormats.isoDate),
          endDate: dateFormat(this.endDate, dateFormats.isoDate),
          firstPageSize: this.pagination.firstPageSize,
          lastPageSize: this.pagination.lastPageSize,
          prevPageCursor: this.pagination.prevPageCursor,
          nextPageCursor: this.pagination.nextPageCursor,
          ...this.options,
        };
      },
      update(data) {
        const { mergeRequests: { nodes: list = [], pageInfo = {} } = {} } = data.project || {};
        return {
          list,
          pageInfo,
        };
      },
      error() {
        this.hasError = true;
      },
    },
  },
  computed: {
    ...mapState('filters', {
      selectedSourceBranch: (state) => state.branches.source.selected,
      selectedTargetBranch: (state) => state.branches.target.selected,
      selectedMilestone: (state) => state.milestones.selected,
      selectedAuthor: (state) => state.authors.selected,
      selectedAssignee: (state) => state.assignees.selected,
      selectedLabelList: (state) => state.labels.selectedList,
    }),
    options() {
      const options = filterToQueryObject({
        sourceBranches: this.selectedSourceBranch,
        targetBranches: this.selectedTargetBranch,
        milestoneTitle: this.selectedMilestone,
        authorUsername: this.selectedAuthor,
        assigneeUsername: this.selectedAssignee,
        labels: this.selectedLabelList,
      });

      return {
        ...options,
        notLabels: options['not[labels]'],
        notMilestoneTitle: options['not[milestoneTitle]'],
      };
    },
    tableDataAvailable() {
      return this.throughputTableData.list?.length;
    },
    tableDataLoading() {
      return !this.hasError && this.$apollo.queries.throughputTableData.loading;
    },
    alertDetails() {
      return {
        class: this.hasError ? 'danger' : 'info',
        message: this.hasError
          ? THROUGHPUT_TABLE_STRINGS.ERROR_FETCHING_DATA
          : THROUGHPUT_TABLE_STRINGS.NO_DATA,
      };
    },
  },
  watch: {
    options() {
      this.resetPagination();
    },
  },
  methods: {
    handlePageChange({ pagination }) {
      const { prevPageCursor, nextPageCursor } = pagination;

      if (nextPageCursor) {
        this.pagination = {
          ...initialPaginationState,
          nextPageCursor,
        };
      } else {
        this.pagination = {
          lastPageSize: PER_PAGE,
          firstPageSize: null,
          prevPageCursor,
        };
      }
    },
    resetPagination() {
      this.pagination = initialPaginationState;
    },
  },
};
</script>
<template>
  <gl-loading-icon v-if="tableDataLoading" size="lg" />
  <throughput-table
    v-else-if="tableDataAvailable"
    :data="throughputTableData"
    @updateQuery="handlePageChange"
  />
  <gl-alert v-else :variant="alertDetails.class" :dismissible="false" class="gl-mt-4">{{
    alertDetails.message
  }}</gl-alert>
</template>
