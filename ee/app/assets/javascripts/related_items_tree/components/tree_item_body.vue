<script>
import {
  GlButton,
  GlIcon,
  GlLabel,
  GlLink,
  GlModalDirective,
  GlTooltip,
  GlTooltipDirective,
} from '@gitlab/ui';
import { isEmpty, isNumber } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';

import ItemWeight from 'ee_component/issues/components/issue_weight.vue';
import ItemDueDate from '~/boards/components/issue_due_date.vue';
import { __ } from '~/locale';
import { isScopedLabel } from '~/lib/utils/common_utils';

import isShowingLabelsQuery from '~/graphql_shared/client/is_showing_labels.query.graphql';
import ItemAssignees from '~/issuable/components/issue_assignees.vue';
import ItemMilestone from '~/issuable/components/issue_milestone.vue';
import { STATUS_CLOSED, STATUS_OPEN } from '~/issues/constants';

import { ChildType, itemRemoveModalId } from '../constants';
import EpicHealthStatus from './epic_health_status.vue';
import IssueHealthStatus from './issue_health_status.vue';

import StateTooltip from './state_tooltip.vue';

export default {
  itemRemoveModalId,
  components: {
    GlIcon,
    GlLabel,
    GlLink,
    GlTooltip,
    GlButton,
    StateTooltip,
    ItemMilestone,
    ItemAssignees,
    ItemDueDate,
    ItemWeight,
    EpicHealthStatus,
    IssueHealthStatus,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModalDirective,
  },
  props: {
    parentItem: {
      type: Object,
      required: true,
    },
    labelsFilterParam: {
      type: String,
      required: false,
      default: 'label_name',
    },
    item: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    isShowingLabels: {
      query: isShowingLabelsQuery,
      update: (data) => data.isShowingLabels,
    },
  },
  computed: {
    ...mapState([
      'allowIssuableHealthStatus',
      'allowScopedLabels',
      'allowSubEpics',
      'childrenFlags',
      'epicsWebUrl',
      'issuesWebUrl',
      'userSignedIn',
    ]),
    itemReference() {
      return this.item.reference;
    },
    itemWebPath() {
      // Here, GraphQL API (during item fetch) returns `webPath`
      // and Rails API (during item add) returns `path`,
      // we need to make both accessible.
      return this.item.path || this.item.webPath;
    },
    isOpen() {
      return this.item.state === STATUS_OPEN;
    },
    isBlocked() {
      return this.item.blocked;
    },
    isClosed() {
      return this.item.state === STATUS_CLOSED;
    },
    hasMilestone() {
      return !isEmpty(this.item.milestone);
    },
    hasAssignees() {
      return this.item.assignees && this.item.assignees.length > 0;
    },
    hasWeight() {
      return isNumber(this.item.weight);
    },
    showLabels() {
      return this.isShowingLabels && this.item.labels?.length > 0;
    },
    stateText() {
      return this.isOpen ? __('Created') : __('Closed');
    },
    stateIconName() {
      if (this.item.type === ChildType.Epic) {
        return this.isOpen ? 'epic' : 'epic-closed';
      }
      if (this.isBlocked && this.isOpen) {
        return 'entity-blocked';
      }
      return this.isOpen ? 'issues' : 'issue-closed';
    },
    stateIconVariant() {
      if (this.isBlocked && this.isOpen) {
        return 'danger';
      }
      return this.isOpen ? 'success' : 'info';
    },
    itemId() {
      return this.itemReference.split(this.item.pathIdSeparator).pop();
    },
    itemPath() {
      return this.itemReference.split(this.item.pathIdSeparator)[0];
    },
    itemHierarchy() {
      return this.itemPath + this.item.pathIdSeparator + this.itemId;
    },
    computedPath() {
      return this.itemWebPath.length ? this.itemWebPath : null;
    },
    canAdminRelation() {
      if (this.isEpic) {
        return this.parentItem.userPermissions.canReadRelation;
      }

      return this.parentItem.userPermissions.canAdminRelation;
    },
    itemActionInProgress() {
      return (
        this.childrenFlags[this.itemReference].itemChildrenFetchInProgress ||
        this.childrenFlags[this.itemReference].itemRemoveInProgress
      );
    },
    showEmptySpacer() {
      return !this.canAdminRelation && this.userSignedIn;
    },
    totalEpicsCount() {
      const { descendantCounts: { openedEpics = 0, closedEpics = 0 } = {} } = this.item;

      return openedEpics + closedEpics;
    },
    totalIssuesCount() {
      const { descendantCounts: { openedIssues = 0, closedIssues = 0 } = {} } = this.item;

      return openedIssues + closedIssues;
    },
    isEpic() {
      return this.item.type === ChildType.Epic;
    },
    isIssue() {
      return this.item.type === ChildType.Issue;
    },
    showHealthStatus() {
      return this.item.healthStatus && this.allowIssuableHealthStatus;
    },
    showIssueHealthStatus() {
      return this.isIssue && this.isOpen && this.showHealthStatus;
    },
    showEpicHealthStatus() {
      const { descendantCounts: { openedIssues = 0 } = {} } = this.item;
      return this.isEpic && this.showHealthStatus && openedIssues > 0;
    },
  },
  methods: {
    ...mapActions(['setRemoveItemModalProps']),
    handleRemoveClick() {
      const { parentItem, item } = this;

      this.setRemoveItemModalProps({
        parentItem,
        item,
      });
    },
    showScopedLabel(label) {
      return isScopedLabel(label) && this.allowScopedLabels;
    },
    labelFilterUrl(label) {
      let basePath = this.issuesWebUrl;

      if (this.isEpic) {
        basePath = this.epicsWebUrl;
      }

      return `${basePath}?${this.labelsFilterParam}[]=${encodeURIComponent(label.title)}`;
    },
  },
};
</script>

<template>
  <div class="sortable-row gl-grow">
    <div
      class="item-body -gl-mx-2 gl-flex gl-items-center gl-py-2 gl-pl-3 gl-pr-2"
      :class="{
        'item-logged-out': !userSignedIn,
        'item-closed': isClosed,
      }"
    >
      <div class="gl-flex gl-grow gl-flex-nowrap gl-items-center">
        <div class="item-title-wrapper gl-mr-3 gl-grow">
          <div class="item-title gl-mb-0 gl-flex gl-py-1">
            <gl-icon
              ref="stateIconMd"
              class="issue-token-state-icon gl-mr-3 gl-block"
              :name="stateIconName"
              :aria-label="stateText"
              :variant="stateIconVariant"
            />
            <state-tooltip
              :get-target-ref="() => $refs.stateIconMd"
              :path="itemHierarchy"
              :is-open="isOpen"
              :state="item.state"
              :created-at="item.createdAt"
              :closed-at="item.closedAt || ''"
            />
            <gl-icon
              v-if="item.confidential"
              v-gl-tooltip.hover
              :title="__('Confidential')"
              :aria-label="__('Confidential')"
              name="eye-slash"
              class="align-self-baseline align-self-md-auto mt-xl-0 gl-mr-2"
              variant="warning"
            />
            <gl-link
              v-gl-tooltip.hover
              :aria-label="item.title"
              :title="item.title"
              :href="computedPath"
              class="sortable-link ws-normal gl-font-bold"
              >{{ item.title }}</gl-link
            >
          </div>

          <div class="item-meta mt-xl-0 gl-ml-6 gl-flex gl-flex-wrap gl-items-center gl-text-sm">
            <span class="gl-mb-1 gl-mr-4">{{ itemHierarchy }}</span>
            <gl-tooltip v-if="isEpic" :target="() => $refs.countBadge">
              <p v-if="allowSubEpics" class="gl-m-0 gl-font-bold">
                {{ __('Epics') }} &#8226;
                <span class="gl-font-normal gl-text-subtle"
                  >{{
                    sprintf(__('%{openedEpics} open, %{closedEpics} closed'), {
                      openedEpics: item.descendantCounts && item.descendantCounts.openedEpics,
                      closedEpics: item.descendantCounts && item.descendantCounts.closedEpics,
                    })
                  }}
                </span>
              </p>
              <p class="gl-m-0 gl-font-bold">
                {{ __('Issues') }} &#8226;
                <span class="gl-font-normal gl-text-subtle"
                  >{{
                    sprintf(__('%{openedIssues} open, %{closedIssues} closed'), {
                      openedIssues: item.descendantCounts && item.descendantCounts.openedIssues,
                      closedIssues: item.descendantCounts && item.descendantCounts.closedIssues,
                    })
                  }}
                </span>
              </p>
            </gl-tooltip>

            <div
              v-if="isEpic"
              ref="countBadge"
              class="p-lg-0 gl-inline-flex gl-py-0 gl-text-subtle"
            >
              <span v-if="allowSubEpics" class="gl-mb-1 gl-mr-4 gl-inline-flex gl-items-center">
                <gl-icon name="epic" class="gl-mr-2" />
                {{ totalEpicsCount }}
              </span>
              <span class="gl-mb-1 gl-mr-4 gl-inline-flex gl-items-center">
                <gl-icon name="issues" class="gl-mr-2" />
                {{ totalIssuesCount }}
              </span>
            </div>

            <item-milestone
              v-if="hasMilestone"
              :milestone="item.milestone"
              class="item-milestone gl-mb-1 gl-mr-4 gl-flex gl-items-center"
            />

            <item-due-date
              v-if="item.dueDate"
              :date="item.dueDate"
              :closed="Boolean(item.closedAt)"
              tooltip-placement="top"
              css-class="item-due-date gl-flex gl-items-center !gl-mr-4 gl-mb-1"
            />

            <item-weight
              v-if="hasWeight"
              :weight="item.weight"
              class="item-weight !gl-mr-4 gl-mb-1 gl-flex gl-items-center"
            />

            <item-assignees
              v-if="hasAssignees"
              :assignees="item.assignees"
              class="item-assignees flex-xl-grow-0 gl-mb-1 gl-mr-4 gl-inline-flex gl-items-center"
            />

            <epic-health-status
              v-if="showEpicHealthStatus"
              :health-status="item.healthStatus"
              class="gl-mb-1 gl-mr-4"
            />
            <issue-health-status
              v-if="showIssueHealthStatus"
              :health-status="item.healthStatus"
              class="gl-mb-1 gl-mr-4"
            />

            <template v-if="showLabels">
              <gl-label
                v-for="label in item.labels"
                :key="label.id"
                :background-color="label.color"
                :description="label.description"
                :scoped="showScopedLabel(label)"
                :target="labelFilterUrl(label)"
                :title="label.title"
                class="gl-mb-1 gl-mr-2"
                tooltip-placement="top"
              />
            </template>
          </div>
        </div>

        <gl-button
          v-if="canAdminRelation"
          v-gl-tooltip.hover
          v-gl-modal-directive="$options.itemRemoveModalId"
          category="tertiary"
          size="small"
          :title="__('Remove')"
          :aria-label="__('Remove')"
          :disabled="itemActionInProgress"
          icon="close"
          class="js-issue-item-remove-button gl-self-start"
          data-testid="remove-issue-button"
          @click="handleRemoveClick"
        />
        <span v-if="showEmptySpacer" class="gl-p-3"></span>
      </div>
    </div>
  </div>
</template>
