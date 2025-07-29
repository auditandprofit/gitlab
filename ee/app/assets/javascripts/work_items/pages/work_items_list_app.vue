<script>
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { GlEmptyState } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { findStatusWidget } from '~/work_items/utils';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import {
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_ISSUE,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  OPERATORS_IS,
  TOKEN_TYPE_STATUS,
  TOKEN_TITLE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TOKEN_TITLE_WEIGHT,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_HEALTH,
  TOKEN_TITLE_HEALTH,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import WorkItemStatusToken from 'ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue';

import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';

const CustomFieldToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue');
const WeightToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue');
const HealthToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue');

export default {
  emptyStateSvg,
  WORK_ITEM_TYPE_NAME_EPIC,
  components: {
    CreateWorkItemModal,
    EmptyStateWithAnyIssues,
    GlEmptyState,
    WorkItemsListApp,
    WorkItemStatusBadge,
  },
  inject: [
    'hasEpicsFeature',
    'isGroup',
    'showNewWorkItem',
    'workItemType',
    'hasCustomFieldsFeature',
    'hasIssueWeightsFeature',
    'hasIssuableHealthStatusFeature',
    'hasStatusFeature',
  ],
  props: {
    withTabs: {
      type: Boolean,
      required: false,
      default: true,
    },
    rootPageFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      workItemUpdateCount: 0,
      customFields: [],
    };
  },
  apollo: {
    customFields: {
      query: namespaceCustomFieldsQuery,
      variables() {
        return {
          fullPath: this.rootPageFullPath,
          active: true,
        };
      },
      skip() {
        return !this.hasCustomFieldsFeature;
      },
      update(data) {
        return (data.namespace?.customFields?.nodes || []).filter((field) => {
          const fieldTypeAllowed = [
            CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          ].includes(field.fieldType);
          const fieldAllowedOnWorkItem = field.workItemTypes.some(
            (type) => type.name === this.workItemType,
          );

          return fieldTypeAllowed && fieldAllowedOnWorkItem;
        });
      },
      error(error) {
        createAlert({
          message: s__('WorkItem|Failed to load custom fields.'),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    preselectedWorkItemType() {
      return this.isEpicsList ? WORK_ITEM_TYPE_NAME_EPIC : WORK_ITEM_TYPE_NAME_ISSUE;
    },
    isEpicsList() {
      return this.workItemType === WORK_ITEM_TYPE_NAME_EPIC;
    },
    searchTokens() {
      const tokens = [];

      if (this.customFields.length > 0) {
        this.customFields.forEach((field) => {
          tokens.push({
            type: `${TOKEN_TYPE_CUSTOM_FIELD}[${getIdFromGraphQLId(field.id)}]`,
            title: field.name,
            icon: 'multiple-choice',
            field,
            fullPath: this.rootPageFullPath,
            token: CustomFieldToken,
            operators: OPERATORS_IS,
            unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          });
        });
      }

      if (this.hasIssueWeightsFeature && !this.isEpicsList) {
        tokens.push({
          type: TOKEN_TYPE_WEIGHT,
          title: TOKEN_TITLE_WEIGHT,
          icon: 'weight',
          token: WeightToken,
          unique: true,
        });
      }
      if (this.showCustomStatusFeature) {
        tokens.push({
          type: TOKEN_TYPE_STATUS,
          title: TOKEN_TITLE_STATUS,
          icon: 'status',
          token: WorkItemStatusToken,
          fullPath: this.rootPageFullPath,
          unique: true,
          operators: OPERATORS_IS,
        });
      }

      if (this.hasIssuableHealthStatusFeature) {
        tokens.push({
          type: TOKEN_TYPE_HEALTH,
          title: TOKEN_TITLE_HEALTH,
          icon: 'status-health',
          token: HealthToken,
          unique: true,
        });
      }

      return tokens;
    },
    showCustomStatusFeature() {
      return this.hasStatusFeature && !this.isEpicsList;
    },
  },
  methods: {
    incrementUpdateCount() {
      this.workItemUpdateCount += 1;
    },
    hasStatus(issuable) {
      return findStatusWidget(issuable);
    },
    issuableStatusItem(issuable) {
      return findStatusWidget(issuable)?.status || {};
    },
  },
};
</script>

<template>
  <work-items-list-app
    :ee-work-item-update-count="workItemUpdateCount"
    :ee-search-tokens="searchTokens"
    :root-page-full-path="rootPageFullPath"
    :with-tabs="withTabs"
  >
    <template v-if="isEpicsList && hasEpicsFeature" #list-empty-state="{ hasSearch, isOpenTab }">
      <empty-state-with-any-issues
        :has-search="hasSearch"
        :is-epic="isEpicsList"
        :is-open-tab="isOpenTab"
      >
        <template v-if="showNewWorkItem" #new-issue-button>
          <create-work-item-modal
            class="gl-grow"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="preselectedWorkItemType"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </empty-state-with-any-issues>
    </template>
    <template v-if="isEpicsList && hasEpicsFeature" #page-empty-state>
      <gl-empty-state
        :description="
          __('Track groups of issues that share a theme, across projects and milestones')
        "
        :svg-path="$options.emptyStateSvg"
        :title="
          __(
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
          )
        "
      >
        <template v-if="showNewWorkItem" #actions>
          <create-work-item-modal
            class="gl-grow"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="$options.WORK_ITEM_TYPE_NAME_EPIC"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </gl-empty-state>
    </template>
    <template #custom-status="{ issuable = {} }">
      <work-item-status-badge v-if="hasStatus(issuable)" :item="issuableStatusItem(issuable)" />
    </template>
  </work-items-list-app>
</template>
