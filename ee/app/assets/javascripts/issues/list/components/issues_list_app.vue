<script>
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_STATUS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  OPERATORS_IS,
  TOKEN_TITLE_EPIC,
  TOKEN_TITLE_HEALTH,
  TOKEN_TITLE_ITERATION,
  TOKEN_TITLE_WEIGHT,
  TOKEN_TYPE_HEALTH,
  TOKEN_TYPE_CUSTOM_FIELD,
  TOKEN_TITLE_STATUS,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import { CUSTOM_FIELDS_TYPE_MULTI_SELECT } from '~/work_items/constants';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_EPIC, TYPENAME_ISSUE, TYPENAME_TASK } from '~/graphql_shared/constants';
import searchIterationsQuery from '../queries/search_iterations.query.graphql';
import NewIssueDropdown from './new_issue_dropdown.vue';

const EpicToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/epic_token.vue');
const IterationToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/iteration_token.vue');
const WeightToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/weight_token.vue');
const HealthToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/health_token.vue');
const ChildEpicIssueIndicator = () =>
  import('ee/issuable/child_epic_issue_indicator/components/child_epic_issue_indicator.vue');
const CustomFieldToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue');
const WorkItemStatusToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/work_item_status_token.vue');

export default {
  name: 'IssuesListAppEE',
  components: {
    IssuesListApp: () => import('~/issues/list/components/issues_list_app.vue'),
    NewIssueDropdown,
    ChildEpicIssueIndicator,
    WorkItemStatusBadge,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'fullPath',
    'groupPath',
    'hasCustomFieldsFeature',
    'hasIssueWeightsFeature',
    'hasIterationsFeature',
    'hasIssuableHealthStatusFeature',
    'hasOkrsFeature',
    'isProject',
    'hasStatusFeature',
  ],
  data() {
    return {
      filterParams: null,
      customFields: [],
    };
  },
  apollo: {
    customFields: {
      query: namespaceCustomFieldsQuery,
      skip() {
        return !this.hasCustomFieldsFeature || !this.fullPath;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          active: true,
        };
      },
      update(data) {
        return (data.namespace?.customFields?.nodes || []).filter((field) => {
          const fieldTypeAllowed = ['SINGLE_SELECT', 'MULTI_SELECT'].includes(field.fieldType);
          const fieldAllowedOnWorkItem = field.workItemTypes.some(
            (type) => type.name === TYPENAME_ISSUE || type.name === TYPENAME_TASK,
          );

          return fieldTypeAllowed && fieldAllowedOnWorkItem;
        });
      },
      error(error) {
        createAlert({
          message: s__('WorkItemCustomFields|Failed to load custom fields.'),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    namespace() {
      return this.isProject ? WORKSPACE_PROJECT : WORKSPACE_GROUP;
    },
    isOkrsEnabled() {
      return this.hasOkrsFeature && this.glFeatures.okrsMvc;
    },
    showCustomStatusFilter() {
      return this.glFeatures.workItemStatusFeatureFlag && this.hasStatusFeature;
    },
    searchTokens() {
      const tokens = [];

      if (this.hasIterationsFeature) {
        tokens.push({
          type: TOKEN_TYPE_ITERATION,
          title: TOKEN_TITLE_ITERATION,
          icon: 'iteration',
          token: IterationToken,
          fetchIterations: this.fetchIterations,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-iteration`,
          fullPath: this.fullPath,
          isProject: this.isProject,
        });
      }

      if (this.groupPath) {
        tokens.push({
          type: TOKEN_TYPE_EPIC,
          title: TOKEN_TITLE_EPIC,
          icon: 'epic',
          token: EpicToken,
          unique: true,
          symbol: '&',
          idProperty: 'id',
          useIdValue: true,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-epic`,
          fullPath: this.groupPath,
        });
      }

      if (this.hasIssueWeightsFeature) {
        tokens.push({
          type: TOKEN_TYPE_WEIGHT,
          title: TOKEN_TITLE_WEIGHT,
          icon: 'weight',
          token: WeightToken,
          unique: true,
        });
      }

      if (this.hasIssuableHealthStatusFeature) {
        tokens.push({
          type: TOKEN_TYPE_HEALTH,
          title: TOKEN_TITLE_HEALTH,
          icon: 'status-health',
          token: HealthToken,
          unique: false,
        });
      }

      if (this.customFields.length > 0) {
        this.customFields.forEach((field) => {
          tokens.push({
            type: `${TOKEN_TYPE_CUSTOM_FIELD}[${getIdFromGraphQLId(field.id)}]`,
            title: field.name,
            icon: 'multiple-choice',
            field,
            fullPath: this.fullPath,
            token: CustomFieldToken,
            operators: OPERATORS_IS,
            unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          });
        });
      }

      if (this.showCustomStatusFilter) {
        tokens.push({
          type: TOKEN_TYPE_STATUS,
          title: TOKEN_TITLE_STATUS,
          icon: 'status',
          token: WorkItemStatusToken,
          fullPath: this.fullPath,
          unique: true,
          operators: OPERATORS_IS,
        });
      }

      return tokens;
    },
    searchedByEpic() {
      return Boolean(this.filterParams?.epicId);
    },
    showNewIssueDropdown() {
      return this.isOkrsEnabled && this.isProject && !this.glFeatures.issuesListCreateModal;
    },
  },
  methods: {
    refetchIssuables() {
      this.$refs.issuesListApp.$apollo.queries.issues.refetch();
      this.$refs.issuesListApp.$apollo.queries.issuesCounts.refetch();
    },
    fetchIterations(search) {
      const id = Number(search);
      const variables =
        !search || Number.isNaN(id)
          ? { fullPath: this.fullPath, search, isProject: this.isProject }
          : { fullPath: this.fullPath, id, isProject: this.isProject };

      variables.state = 'all';

      return this.$apollo
        .query({
          query: searchIterationsQuery,
          variables,
        })
        .then(({ data }) => data[this.namespace]?.iterations.nodes);
    },
    hasFilteredEpicId(apiFilterParams) {
      return Boolean(apiFilterParams.epicId);
    },
    hasCustomStatus(issuable) {
      return issuable.status;
    },
    getFilteredEpicId(apiFilterParams) {
      const { epicId } = apiFilterParams;

      if (!epicId) {
        return '';
      }

      return convertToGraphQLId(TYPENAME_EPIC, parseInt(epicId, 10));
    },
  },
};
</script>

<template>
  <issues-list-app
    ref="issuesListApp"
    :ee-search-tokens="searchTokens"
    :searched-by-epic="searchedByEpic"
    @updateFilterParams="filterParams = $event"
  >
    <template v-if="showNewIssueDropdown" #new-issuable-button>
      <new-issue-dropdown :full-path="fullPath" @workItemCreated="refetchIssuables" />
    </template>
    <template #title-icons="{ issuable, apiFilterParams }">
      <child-epic-issue-indicator
        v-if="hasFilteredEpicId(apiFilterParams)"
        class="gl-ml-2"
        :filtered-epic-id="getFilteredEpicId(apiFilterParams)"
        :issuable="issuable"
      />
    </template>
    <template #custom-status="{ issuable }">
      <li class="gl-max-w-full">
        <work-item-status-badge v-if="hasCustomStatus(issuable)" :item="issuable.status" />
      </li>
    </template>
  </issues-list-app>
</template>
