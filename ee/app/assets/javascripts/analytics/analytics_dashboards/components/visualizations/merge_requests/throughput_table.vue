<script>
import {
  GlTableLite,
  GlLink,
  GlAvatarLink,
  GlAvatar,
  GlAvatarsInline,
  GlTooltipDirective,
  GlIcon,
  GlKeysetPagination,
} from '@gitlab/ui';
import {
  MERGE_REQUEST_ID_PREFIX,
  LINE_CHANGE_SYMBOLS,
  ASSIGNEES_VISIBLE,
  AVATAR_SIZE,
  PER_PAGE,
  THROUGHPUT_TABLE_TEST_IDS,
  PIPELINE_STATUS_ICON_CLASSES,
  THROUGHPUT_TABLE_HEADER_FIELDS,
} from 'ee/analytics/merge_request_analytics/constants';
import { dateFormats } from '~/analytics/shared/constants';
import dateFormat from '~/lib/dateformat';
import { approximateDuration, differenceInSeconds } from '~/lib/utils/datetime_utility';
import { n__ } from '~/locale';

export default {
  name: 'ThroughputTable',
  components: {
    GlTableLite,
    GlLink,
    GlAvatarLink,
    GlAvatar,
    GlAvatarsInline,
    GlIcon,
    GlKeysetPagination,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  tableHeaderFields: THROUGHPUT_TABLE_HEADER_FIELDS,
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
  computed: {
    pagination() {
      return this.data.pageInfo;
    },
    showPaginationControls() {
      return Boolean(this.pagination.hasPreviousPage || this.pagination.hasNextPage);
    },
  },
  methods: {
    formatMergeRequestId(id) {
      return `${MERGE_REQUEST_ID_PREFIX}${id}`;
    },
    formatLineChangeAdditions(value) {
      return `${LINE_CHANGE_SYMBOLS.ADDITIONS}${value}`;
    },
    formatLineChangeDeletions(value) {
      return `${LINE_CHANGE_SYMBOLS.DELETIONS}${value}`;
    },
    formatDateMerged(value) {
      return dateFormat(value, dateFormats.isoDate);
    },
    computeTimeToMerge(createdAt, mergedAt) {
      return approximateDuration(differenceInSeconds(new Date(createdAt), new Date(mergedAt)));
    },
    pipelineStatusClass(value) {
      return PIPELINE_STATUS_ICON_CLASSES[value] === undefined
        ? PIPELINE_STATUS_ICON_CLASSES.default
        : PIPELINE_STATUS_ICON_CLASSES[value];
    },
    formatApprovalText(approvals) {
      return n__('%d Approval', '%d Approvals', approvals);
    },
    nextPage() {
      const { endCursor } = this.pagination;

      this.$emit('updateQuery', {
        pagination: {
          firstPageSize: PER_PAGE,
          nextPageCursor: endCursor,
        },
      });
    },
    prevPage() {
      const { startCursor } = this.pagination;
      this.$emit('updateQuery', {
        pagination: {
          lastPageSize: PER_PAGE,
          prevPageCursor: startCursor,
        },
      });
    },
    hasPipelineNodes(item) {
      return item.pipelines?.nodes;
    },
    assigneesBadgeSrOnlyText(item) {
      return n__(
        '%d additional assignee',
        '%d additional assignees',
        item.assignees.nodes.length - this.$options.assigneesVisible,
      );
    },
  },
  assigneesVisible: ASSIGNEES_VISIBLE,
  avatarSize: AVATAR_SIZE,
  testIds: THROUGHPUT_TABLE_TEST_IDS,
};
</script>
<template>
  <div>
    <gl-table-lite
      :fields="$options.tableHeaderFields"
      :items="data.list"
      stacked="sm"
      thead-class="gl-bg-default gl-border-t-0 gl-border-b-solid gl-border-b-1 gl-border-b-default"
      data-testid="mr-table"
    >
      <template #cell(mr_details)="{ item }">
        <div
          class="gl-flex gl-grow gl-flex-col"
          :data-testid="$options.testIds.MERGE_REQUEST_DETAILS"
        >
          <div class="merge-request-title gl-str-truncated">
            <gl-link :href="item.webUrl" target="_blank" class="gl-font-bold gl-text-default">{{
              item.title
            }}</gl-link>
            <ul class="horizontal-list gl-mb-0 gl-mt-2">
              <li class="gl-mr-3">{{ formatMergeRequestId(item.iid) }}</li>
              <li v-if="hasPipelineNodes(item) && item.pipelines.nodes.length" class="gl-mr-3">
                <gl-icon
                  :name="item.pipelines.nodes[0].detailedStatus.icon"
                  :class="pipelineStatusClass(item.pipelines.nodes[0].detailedStatus.icon)"
                />
              </li>
              <li
                class="gl-mr-3 gl-flex gl-items-center"
                :class="{ 'gl-opacity-5': !item.labels.count }"
                :data-testid="$options.testIds.LABEL_DETAILS"
              >
                <gl-icon name="label" class="gl-mr-1" /><span>{{ item.labels.count }}</span>
              </li>
              <li
                class="gl-mr-3 gl-flex gl-items-center"
                :class="{ 'gl-opacity-5': !item.userNotesCount }"
                :data-testid="$options.testIds.COMMENT_COUNT"
              >
                <gl-icon name="comments" class="gl-mr-2" /><span>{{ item.userNotesCount }}</span>
              </li>
              <li
                v-if="item.approvedBy.nodes.length"
                class="gl-text-success"
                :data-testid="$options.testIds.APPROVED"
              >
                <gl-icon name="approval" class="gl-mr-2" variant="success" /><span>{{
                  formatApprovalText(item.approvedBy.nodes.length)
                }}</span>
              </li>
            </ul>
          </div>
        </div>
      </template>

      <template #cell(date_merged)="{ item }">
        <div :data-testid="$options.testIds.DATE_MERGED">{{ formatDateMerged(item.mergedAt) }}</div>
      </template>

      <template #cell(time_to_merge)="{ item }">
        <div :data-testid="$options.testIds.TIME_TO_MERGE">
          {{ computeTimeToMerge(item.createdAt, item.mergedAt) }}
        </div>
      </template>

      <template #cell(milestone)="{ item }">
        <div v-if="item.milestone" :data-testid="$options.testIds.MILESTONE">
          {{ item.milestone.title }}
        </div>
      </template>

      <template #cell(commits)="{ item }">
        <div :data-testid="$options.testIds.COMMITS">{{ item.commitCount }}</div>
      </template>

      <template #cell(pipelines)="{ item }">
        <div v-if="hasPipelineNodes(item)" :data-testid="$options.testIds.PIPELINES">
          {{ item.pipelines.nodes.length }}
        </div>
      </template>

      <template #cell(line_changes)="{ item }">
        <div :data-testid="$options.testIds.LINE_CHANGES">
          <span class="gl-font-bold gl-text-success">{{
            formatLineChangeAdditions(item.diffStatsSummary.additions)
          }}</span>
          <span class="gl-font-bold gl-text-red-500">{{
            formatLineChangeDeletions(item.diffStatsSummary.deletions)
          }}</span>
        </div>
      </template>

      <template #cell(assignees)="{ item }">
        <div :data-testid="$options.testIds.ASSIGNEES">
          <gl-avatars-inline
            :avatars="item.assignees.nodes"
            :avatar-size="$options.avatarSize"
            :max-visible="$options.assigneesVisible"
            :badge-sr-only-text="assigneesBadgeSrOnlyText(item)"
            collapsed
          >
            <template #avatar="{ avatar }">
              <gl-avatar-link
                v-gl-tooltip
                target="_blank"
                :href="avatar.webUrl"
                :title="avatar.name"
              >
                <gl-avatar :src="avatar.avatarUrl" :size="$options.avatarSize" />
              </gl-avatar-link>
            </template>
          </gl-avatars-inline>
        </div>
      </template>
    </gl-table-lite>
    <gl-keyset-pagination
      v-if="showPaginationControls"
      class="gl-m-3 gl-flex gl-items-center gl-justify-center"
      v-bind="pagination"
      @prev="prevPage"
      @next="nextPage"
    />
  </div>
</template>
