<script>
import { __ } from '~/locale';
import SidebarDropdownWidget from '~/sidebar/components/sidebar_dropdown_widget.vue';
import { TYPE_ISSUE, TYPE_MERGE_REQUEST, TYPE_EPIC } from '~/issues/constants';
import { WORK_ITEM_TYPE_NAME_EPIC } from '~/work_items/constants';
import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_WORK_ITEM, TYPENAME_ISSUE } from '~/graphql_shared/constants';
import { createAlert } from '~/alert';
import { findHierarchyWidget } from '~/work_items/utils';
import {
  dropdowni18nText,
  IssuableAttributeType,
  IssuableAttributeState,
  LocalizedIssuableAttributeType,
  IssuableAttributeTypeKeyMap,
  SIDEBAR_ESCALATION_POLICY_TITLE,
} from 'ee_else_ce/sidebar/constants';
import { issuableAttributesQueries } from '../queries/constants';

const widgetTitleText = {
  [IssuableAttributeType.Milestone]: __('Milestone'),
  [IssuableAttributeType.Iteration]: __('Iteration'),
  [IssuableAttributeType.Epic]: __('Epic'),
  [IssuableAttributeType.EscalationPolicy]: SIDEBAR_ESCALATION_POLICY_TITLE,
  none: __('None'),
  expired: __('(expired)'),
};

export default {
  components: { SidebarDropdownWidget },
  provide: {
    issuableAttributesQueries,
    widgetTitleText,
    issuableAttributesState: IssuableAttributeState,
  },
  inheritAttrs: false,
  props: {
    issuableAttribute: {
      type: String,
      required: true,
      validator(value) {
        return [
          IssuableAttributeType.Milestone,
          IssuableAttributeType.Iteration,
          IssuableAttributeType.Epic,
          IssuableAttributeType.EscalationPolicy,
        ].includes(value);
      },
    },
    workspacePath: {
      required: true,
      type: String,
    },
    iid: {
      required: true,
      type: String,
    },
    attrWorkspacePath: {
      required: true,
      type: String,
    },
    issuableType: {
      type: String,
      required: true,
      validator(value) {
        return [TYPE_ISSUE, TYPE_MERGE_REQUEST].includes(value);
      },
    },
    icon: {
      type: String,
      required: false,
      default: undefined,
    },
    issueId: {
      type: String,
      required: false,
      default: '',
    },
    showWorkItemEpics: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    issuable: {
      query() {
        const { current } = this.issuableAttributeQuery;
        const { query } = current[this.issuableType];

        return query;
      },
      variables() {
        return {
          fullPath: this.workspacePath,
          iid: this.iid,
        };
      },
      update(data) {
        return data.workspace?.issuable || {};
      },
      result({ data }) {
        this.hasWorkItemParent = data?.workspace?.issuable?.hasParent && this.showWorkItemEpics;
      },
      error(error) {
        createAlert({
          message: this.i18n.currentFetchError,
          captureError: true,
          error,
        });
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    workItem: {
      query() {
        return issuableAttributesQueries[IssuableAttributeType.Parent].current[this.issuableType]
          .query;
      },
      variables() {
        return {
          id: this.issuableId,
        };
      },
      update(data) {
        return data.workspace?.workItems?.nodes[0] || {};
      },
      skip() {
        return !this.hasWorkItemParent;
      },
      result({ data }) {
        if (data?.workItem) {
          this.setParentData(data.workItem);
        }
      },
      error(error) {
        createAlert({
          message: this.i18n.currentFetchError,
          captureError: true,
          error,
        });
      },
      subscribeToMore: {
        document() {
          return issuableAttributesQueries[IssuableAttributeType.Parent].subscription;
        },
        variables() {
          return {
            workItemId: convertToGraphQLId(TYPENAME_WORK_ITEM, getIdFromGraphQLId(this.issuableId)),
          };
        },
        skip() {
          return this.skipRealTimeWorkItemParentUpdates;
        },
        updateQuery(_, { subscriptionData }) {
          if (subscriptionData.data?.workItem) {
            this.setParentData(subscriptionData.data.workItem);
          }
        },
      },
    },
  },
  data() {
    return {
      hasWorkItemParent: false,
    };
  },
  computed: {
    issuableId() {
      return this.issuableType === TYPE_ISSUE
        ? convertToGraphQLId(TYPENAME_ISSUE, this.issueId)
        : this.issueId;
    },
    issuableAttributeQuery() {
      return issuableAttributesQueries[this.issuableAttribute];
    },
    skipRealTimeWorkItemParentUpdates() {
      return this.isEpic && !this.showWorkItemEpics && !this.issuableId;
    },
    i18n() {
      const localizedAttribute =
        LocalizedIssuableAttributeType[IssuableAttributeTypeKeyMap[this.issuableAttribute]];
      return dropdowni18nText(localizedAttribute, this.issuableType);
    },
    isEpic() {
      return this.issuableAttribute === TYPE_EPIC;
    },
  },
  methods: {
    async updateAttribute({ id, workItemType }) {
      this.updating = true;
      let response;
      try {
        if (this.hasWorkItemParent) {
          // setting null if there is parent already assigned
          // to avoid parent already assigned error
          await this.updateWorkItem({
            input: {
              id: this.issuableId,
              hierarchyWidget: { parentId: null },
            },
          });
        } else if (this.isEpic && this.showWorkItemEpics && !this.issuable?.hasParent) {
          // Added checks to avoid getting it fired unnecessarily for other widgets

          // setting null if there is epic already assigned
          // to avoid epic already assigned error
          await this.updateIssuable({
            fullPath: this.workspacePath,
            attributeId: null,
            iid: this.iid,
          });
        }

        // Set actual data for work item epic or legacy epic
        if (workItemType?.name === WORK_ITEM_TYPE_NAME_EPIC) {
          response = await this.updateWorkItem({
            input: {
              id: this.issuableId,
              hierarchyWidget: { parentId: id },
            },
          });
        } else {
          response = await this.updateIssuable({
            fullPath: this.workspacePath,
            attributeId: id,
            iid: this.iid,
          });
        }

        if (response.data.issuableSetAttribute?.errors?.length) {
          createAlert({
            message: response.data.issuableSetAttribute.errors[0],
            captureError: true,
            error: response.data.issuableSetAttribute.errors[0],
          });
        } else {
          this.hasWorkItemParent =
            workItemType?.name === WORK_ITEM_TYPE_NAME_EPIC && this.showWorkItemEpics;
          this.$emit('attribute-updated', response.data);
        }
      } catch (error) {
        createAlert({ message: this.i18n.updateError, captureError: true, error });
      } finally {
        this.updating = false;
      }
    },
    updateWorkItem(variables) {
      const { current } = issuableAttributesQueries[IssuableAttributeType.Parent];
      const { mutation } = current[this.issuableType];

      return this.$apollo.mutate({
        mutation,
        variables,
      });
    },
    updateIssuable(variables) {
      const { current } = this.issuableAttributeQuery;
      const { mutation } = current[this.issuableType];

      return this.$apollo.mutate({
        mutation,
        variables,
      });
    },
    setParentData(workItem) {
      const parent = findHierarchyWidget(workItem)?.parent;

      this.issuable = {
        ...this.issuable,
        attribute: parent
          ? {
              id: parent.id,
              title: parent.title,
              webUrl: parent.webUrl,
            }
          : null,
      };
    },
  },
};
</script>
<template>
  <sidebar-dropdown-widget
    :icon="icon"
    :issuable-type="issuableType"
    :attr-workspace-path="attrWorkspacePath"
    :issuable-attribute="issuableAttribute"
    :iid="iid"
    :workspace-path="workspacePath"
    :show-work-item-epics="showWorkItemEpics"
    :is-epic-attribute="isEpic"
    :issuable-parent="issuable"
    v-bind="$attrs"
    @updateAttribute="updateAttribute"
    v-on="$listeners"
  >
    <template v-for="(_, name) in $scopedSlots" #[name]="slotData">
      <slot :name="name" v-bind="slotData"></slot>
    </template>
  </sidebar-dropdown-widget>
</template>
