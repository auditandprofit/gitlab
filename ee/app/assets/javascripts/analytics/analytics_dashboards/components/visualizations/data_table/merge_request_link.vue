<script>
import { GlIcon, GlLink } from '@gitlab/ui';

export const PIPELINE_STATUS_SUCCESS = 'SUCCESS';
export const PIPELINE_STATUS_PENDING = 'PENDING';
export const PIPELINE_STATUS_FAILED = 'FAILED';

export default {
  name: 'MergeRequestLink',
  components: {
    GlIcon,
    GlLink,
  },
  props: {
    iid: {
      type: Number,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    webUrl: {
      type: String,
      required: true,
    },
    pipelineStatus: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    labelsCount: {
      type: Number,
      required: false,
      default: 0,
    },
    userNotesCount: {
      type: Number,
      required: false,
      default: 0,
    },
    approvalCount: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    iidWithPrefix() {
      return `!${this.iid}`;
    },
    pipelineIcon() {
      const { name, label: ariaLabel } = this.pipelineStatus;

      switch (name) {
        case PIPELINE_STATUS_SUCCESS:
          return {
            name: 'status_success',
            variant: 'success',
            ariaLabel,
          };
        case PIPELINE_STATUS_PENDING:
          return {
            name: 'status_pending',
            variant: 'warning',
            ariaLabel,
          };
        case PIPELINE_STATUS_FAILED:
          return {
            name: 'status_failed',
            variant: 'danger',
            ariaLabel,
          };
        default:
          return undefined;
      }
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-grow gl-flex-col">
    <div class="gl-str-truncated">
      <gl-link :href="webUrl" target="_blank" class="gl-font-bold gl-text-default">{{
        title
      }}</gl-link>
      <ul class="horizontal-list gl-mb-0 gl-mt-2 gl-flex gl-items-center gl-gap-3">
        <li data-testid="mr-iid">{{ iidWithPrefix }}</li>
        <li v-if="pipelineIcon">
          <gl-icon v-bind="pipelineIcon" data-testid="pipeline-icon" />
        </li>
        <li :class="{ 'gl-opacity-5': !labelsCount }" data-testid="labels-count">
          <gl-icon name="label" class="gl-mr-1" />
          <span>{{ labelsCount }}</span>
        </li>
        <li :class="{ 'gl-opacity-5': !userNotesCount }" data-testid="user-notes-count">
          <gl-icon name="comments" class="gl-mr-2" />
          <span>{{ userNotesCount }}</span>
        </li>
        <li v-if="approvalCount" class="gl-text-success" data-testid="approval-count">
          <gl-icon name="approval" class="gl-mr-2" variant="success" />
          <span>{{ n__('%d Approval', '%d Approvals', approvalCount) }}</span>
        </li>
      </ul>
    </div>
  </div>
</template>
