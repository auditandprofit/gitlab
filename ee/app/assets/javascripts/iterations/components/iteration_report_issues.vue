<script>
import {
  GlAlert,
  GlAvatar,
  GlBadge,
  GlButton,
  GlIcon,
  GlLabel,
  GlLink,
  GlPagination,
  GlSkeletonLoader,
  GlTable,
} from '@gitlab/ui';
import { kebabCase } from 'lodash';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { STATUS_OPEN, WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import { isScopedLabel } from '~/lib/utils/common_utils';
import { __, n__, sprintf } from '~/locale';
import { DEFAULT_PAGE_SIZE } from '~/vue_shared/issuable/list/constants';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import iterationIssuesQuery from '../queries/iteration_issues.query.graphql';
import iterationIssuesWithLabelFilterQuery from '../queries/iteration_issues_with_label_filter.query.graphql';

const skeletonLoaderLimit = 5;

export default {
  skeletonLoaderLimit,
  fields: [
    {
      key: 'title',
      label: __('Title'),
      class: '!gl-bg-transparent gl-border-b-1',
    },
    {
      key: 'weight',
      label: __('Weight'),
      class: '!gl-bg-transparent',
      thClass: 'gl-w-12',
    },
    {
      key: 'assignees',
      label: __('Assignees'),
      class: '!gl-bg-transparent',
      thClass: 'gl-w-1/4 xl:gl-w-1/5',
    },
    {
      key: 'status',
      label: __('Status'),
      class: '!gl-bg-transparent gl-truncate',
      thClass: 'gl-w-1/8 sm:gl-w-1/6 xl:gl-w-1/8',
    },
  ],
  components: {
    GlAlert,
    GlAvatar,
    GlBadge,
    GlButton,
    GlIcon,
    GlLabel,
    GlLink,
    GlPagination,
    GlSkeletonLoader,
    GlTable,
    WorkItemTypeIcon,
  },
  apollo: {
    issues: {
      query() {
        return this.label.title ? iterationIssuesWithLabelFilterQuery : iterationIssuesQuery;
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        const { nodes: issues = [], count, pageInfo = {} } = data[this.namespaceType]?.issues || {};

        const list = issues.map((issue) => ({
          ...issue,
          labels: issue?.labels?.nodes || [],
          assignees: issue?.assignees?.nodes || [],
          weight: issue?.weight || null,
        }));

        return {
          pageInfo,
          list,
          count,
        };
      },
      result({ data }) {
        this.$emit('issuesUpdate', {
          count: data[this.namespaceType]?.issues?.count,
          labelId: this.label?.id,
        });
      },
      error() {
        this.error = __('Error loading issues');
      },
    },
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    hasScopedLabelsFeature: {
      type: Boolean,
      required: false,
      default: false,
    },
    iterationId: {
      type: String,
      required: true,
    },
    label: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    namespaceType: {
      type: String,
      required: false,
      default: WORKSPACE_GROUP,
      validator: (value) => [WORKSPACE_GROUP, WORKSPACE_PROJECT].includes(value),
    },
    hasInaccessibleIssues: {
      type: Boolean,
      required: true,
      default: false,
    },
  },
  data() {
    return {
      issues: {
        list: [],
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
        },
      },
      error: '',
      pagination: {
        currentPage: 1,
      },
      isExpanded: true,
    };
  },
  computed: {
    accordionIcon() {
      return this.isExpanded ? 'chevron-down' : 'chevron-right';
    },
    accordionName() {
      return this.isExpanded ? __('Collapse issues') : __('Expand issues');
    },
    pageSize() {
      const labelGroupingPageSize = 5;
      return this.label.title ? labelGroupingPageSize : DEFAULT_PAGE_SIZE;
    },
    shouldShowTable() {
      return this.isExpanded && !this.$apollo.queries.issues.loading;
    },
    queryVariables() {
      const vars = {
        fullPath: this.fullPath,
        id: getIdFromGraphQLId(this.iterationId),
        isGroup: this.namespaceType === WORKSPACE_GROUP,
        labelName: this.label.title,
      };

      if (this.pagination.beforeCursor) {
        vars.beforeCursor = this.pagination.beforeCursor;
        vars.lastPageSize = this.pageSize;
      } else {
        vars.afterCursor = this.pagination.afterCursor;
        vars.firstPageSize = this.pageSize;
      }

      return vars;
    },
    prevPage() {
      return Number(this.issues.pageInfo.hasPreviousPage);
    },
    nextPage() {
      return Number(this.issues.pageInfo.hasNextPage);
    },
    heading() {
      return this.label.title
        ? sprintf(__('Issues with label %{label}'), { label: this.label.title })
        : __('All issues');
    },
    headingId() {
      return kebabCase(this.heading);
    },
    badgeAriaLabel() {
      return n__('%d issue', '%d issues', this.issues.count);
    },
    tbodyTrClass() {
      return this.label.title ? 'gl-bg-subtle' : undefined;
    },
  },
  methods: {
    issueState(state, assigneeCount) {
      if (state === STATUS_OPEN && assigneeCount === 0) {
        return __('Not started');
      }
      if (state === STATUS_OPEN && assigneeCount > 0) {
        return __('In progress');
      }
      return __('Closed');
    },
    handlePageChange(page) {
      const { startCursor, endCursor } = this.issues.pageInfo;

      if (page > this.pagination.currentPage) {
        this.pagination = {
          afterCursor: endCursor,
          currentPage: page,
        };
      } else {
        this.pagination = {
          beforeCursor: startCursor,
          currentPage: page,
        };
      }
    },
    shouldShowScopedLabel(label) {
      return this.hasScopedLabelsFeature && isScopedLabel(label);
    },
    toggleIsExpanded() {
      this.isExpanded = !this.isExpanded;
    },
  },
};
</script>

<template>
  <section :aria-labelledby="headingId">
    <h4 :id="headingId" class="gl-sr-only">{{ heading }}</h4>

    <gl-alert v-if="error" variant="danger" @dismiss="error = ''">
      {{ error }}
    </gl-alert>

    <div v-if="label.title" class="gl-mb-2 gl-flex gl-items-center">
      <gl-button
        category="tertiary"
        :icon="accordionIcon"
        :aria-label="accordionName"
        @click="toggleIsExpanded"
      />
      <gl-label
        class="gl-ml-1"
        :background-color="label.color"
        :description="label.description"
        :scoped="shouldShowScopedLabel(label)"
        show-close-button
        :target="null"
        :title="label.title"
        @close="$emit('removeLabel', label.id)"
      />
      <gl-badge class="gl-ml-2" variant="muted" :aria-label="badgeAriaLabel">
        {{ issues.count }}
      </gl-badge>
    </div>

    <div v-show="$apollo.queries.issues.loading">
      <div v-for="n in $options.skeletonLoaderLimit" :key="n" class="gl-mx-5 gl-my-6">
        <gl-skeleton-loader />
      </div>
    </div>
    <div
      v-if="hasInaccessibleIssues"
      data-testid="has-inaccessible-issues-label"
      class="gl-p-4 gl-pt-0 gl-text-subtle"
    >
      <gl-icon name="eye-slash" class="gl-text-orange-700 dark:gl-text-orange-500" />
      {{ __('This iteration contains confidential items you do not have access to.') }}
    </div>
    <gl-table
      v-show="shouldShowTable"
      :items="issues.list"
      :fields="$options.fields"
      :empty-text="__('No issues found')"
      fixed
      show-empty
      stacked="sm"
      :tbody-tr-class="tbodyTrClass"
      data-testid="iteration-issues-container"
    >
      <template #cell(title)="{ item: { iid, labels, title, webUrl, type } }">
        <div>
          <work-item-type-icon :work-item-type="type" show-tooltip-on-hover />
          <gl-link
            class="gl-font-bold gl-text-default"
            :href="webUrl"
            :title="title"
            data-testid="iteration-issue-link"
            :data-qa-issue-title="title"
            >{{ title }}
          </gl-link>
        </div>
        <!-- TODO: add references.relative (project name) -->
        <!-- Depends on https://gitlab.com/gitlab-org/gitlab/-/issues/222763 -->
        <div class="gl-mt-2 gl-text-subtle">#{{ iid }}</div>
        <div role="group" :aria-label="__('Labels')">
          <gl-label
            v-for="l in labels"
            :key="l.id"
            class="gl-mr-2 gl-mt-2"
            :background-color="l.color"
            :description="l.description"
            :scoped="shouldShowScopedLabel(l)"
            :target="null"
            :title="l.title"
          />
        </div>
      </template>

      <template #cell(assignees)="{ item: { assignees } }">
        <div class="gl-flex gl-flex-col gl-items-end gl-gap-3 sm:gl-items-start">
          <div
            v-for="assignee in assignees"
            :key="assignee.username"
            class="gl-flex gl-items-center gl-gap-3"
          >
            <gl-avatar :src="assignee.avatarUrl" :size="24" />
            <div>
              {{ assignee.name }}
            </div>
          </div>
        </div>
      </template>

      <template #cell(status)="{ item: { state, assignees = [] } }">
        {{ issueState(state, assignees.length) }}
      </template>
    </gl-table>
    <div v-show="isExpanded" class="gl-mt-3">
      <gl-pagination
        :value="pagination.currentPage"
        :prev-page="prevPage"
        :next-page="nextPage"
        align="center"
        class="gl-pagination gl-mt-3"
        @input="handlePageChange"
      />
    </div>
  </section>
</template>
