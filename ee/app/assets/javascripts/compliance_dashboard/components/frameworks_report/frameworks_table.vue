<script>
import Vue from 'vue';
import {
  GlLoadingIcon,
  GlSearchBoxByClick,
  GlTable,
  GlToast,
  GlLink,
  GlSprintf,
  GlButton,
  GlAlert,
  GlDisclosureDropdown,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import FrameworkBadge from '../shared/framework_badge.vue';
import {
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_EXPORT_FRAMEWORK,
  CREATE_FRAMEWORKS_DOCS_URL,
} from '../../constants';
import { isTopLevelGroup, convertFrameworkIdToGraphQl } from '../../utils';
import updateComplianceFrameworkMutation from '../../graphql/mutations/update_compliance_framework.mutation.graphql';
import FrameworkInfoDrawer from './framework_info_drawer.vue';
import DeleteModal from './edit_framework/components/delete_modal.vue';

Vue.use(GlToast);

export default {
  name: 'FrameworksTable',
  components: {
    DeleteModal,
    FrameworkInfoDrawer,
    FrameworkBadge,
    GlLoadingIcon,
    GlSearchBoxByClick,
    GlTable,
    GlLink,
    GlAlert,
    GlDisclosureDropdown,
    GlButton,
    GlSprintf,
    TimeAgo,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['policyDisplayLimit'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
    frameworks: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      frameworkToDeleteName: null,
      frameworkToDeleteId: null,
    };
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },
    hasSearch() {
      // Search is not supported for project frameworks
      return !this.projectPath;
    },
    selectedFramework() {
      return this.$route.query.id
        ? this.frameworks.find(
            (framework) => framework.id === convertFrameworkIdToGraphQl(this.$route.query.id),
          )
        : null;
    },
    showNoFrameworksAlert() {
      return !this.frameworks.length && !this.isLoading && !this.isTopLevelGroup;
    },
    tableFields() {
      const omittedFields = [];
      if (this.projectPath || !this.isTopLevelGroup) {
        omittedFields.push('associatedProjects');
      }

      return omittedFields.length === 0
        ? this.$options.fields
        : this.$options.fields.filter((f) => !omittedFields.includes(f.key));
    },
  },
  methods: {
    getIdFromGraphQLId,
    async toggleDrawer(item) {
      this.closeDrawer();

      if (this.selectedFramework?.id !== item.id) {
        await this.$nextTick();
        this.openDrawer(item);
      }
    },
    copyFrameworkId(id) {
      navigator?.clipboard?.writeText(getIdFromGraphQLId(id));
      this.$toast.show(this.$options.i18n.copyIdToastText);
      this.$refs[`framework-dropdown-${id}`].closeAndFocus();
    },
    showDeleteModal(framework) {
      this.frameworkToDeleteName = framework.name;
      this.frameworkToDeleteId = framework.id;
      this.$refs.deleteModal.show();
    },
    openDrawer(item) {
      this.$router.push({ query: { id: getIdFromGraphQLId(item.id) } });
    },
    closeDrawer() {
      this.$router.push({ query: null });
    },
    isLastItem(index, arr) {
      return index >= arr.length - 1;
    },
    editFramework({ id }) {
      this.$router.push({ name: ROUTE_EDIT_FRAMEWORK, params: { id: getIdFromGraphQLId(id) } });
    },
    async updateDefaultFramework({ framework, isDefault }) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateComplianceFrameworkMutation,
          variables: {
            input: {
              id: framework.id,
              params: {
                default: isDefault,
              },
            },
          },
        });
        const errors = data?.updateComplianceFramework?.errors;

        if (errors && errors.length) {
          throw new Error(errors.join(', '));
        }

        this.$emit('update-frameworks');

        this.$toast.show(
          isDefault
            ? this.$options.i18n.setAsDefaultFrameworkSuccess
            : this.$options.i18n.removeAsDefaultFrameworkSuccess,
        );
      } catch (error) {
        this.$toast.show(
          isDefault
            ? this.$options.i18n.setAsDefaultFrameworkError
            : this.$options.i18n.removeAsDefaultFrameworkError,
        );
        Sentry.captureException(error, {
          tags: {
            vue_component: 'frameworks_table',
          },
        });
      }
    },
    async exportFramework(framework) {
      try {
        const frameworkId = getIdFromGraphQLId(framework.id);
        const downloadUrl = this.$router.resolve({
          name: ROUTE_EXPORT_FRAMEWORK,
          params: {
            id: frameworkId,
          },
        }).href;
        window.location.href = downloadUrl;
        this.$refs[`framework-dropdown-${framework.id}`].closeAndFocus();
      } catch (error) {
        this.$toast.show(s__('ComplianceFrameworksReport|Failed to export framework'));
        Sentry.captureException(error, {
          tags: {
            vue_component: 'frameworks_table',
          },
        });
      }
    },
    getSetAsDefaultActionTooltipTitle(framework) {
      if (framework.default) {
        return this.$options.i18n.removeAsDefaultFrameworkTooltip;
      }
      return this.$options.i18n.setAsDefaultFrameworkTooltip;
    },
    getPoliciesList(item) {
      const {
        scanExecutionPolicies,
        scanResultPolicies,
        pipelineExecutionPolicies,
        vulnerabilityManagementPolicies,
      } = item;
      return [
        ...scanExecutionPolicies.nodes,
        ...scanResultPolicies.nodes,
        ...pipelineExecutionPolicies.nodes,
        ...vulnerabilityManagementPolicies.nodes,
      ]
        .map((x) => x.name)
        .join(',');
    },
    shouldDisableDeleteAction(framework) {
      return framework.default || Boolean(this.getPoliciesList(framework).length);
    },
    getDeleteActionTooltipTitle(framework) {
      if (this.shouldDisableDeleteAction(framework)) {
        return framework.default
          ? this.$options.i18n.deleteButtonDefaultFrameworkDisabledTooltip
          : this.$options.i18n.deleteButtonLinkedPoliciesDisabledTooltip;
      }
      return '';
    },
    remainingProjectsCount(projects) {
      return projects.count - projects.nodes.length;
    },
    remainingRequirementsCount(requirements) {
      return requirements.nodes.length - this.policyDisplayLimit;
    },
    lastVisiblePolicyIndex(requirements) {
      return Math.min(requirements.length, this.policyDisplayLimit) - 1;
    },
  },
  fields: [
    {
      key: 'name',
      label: __('Frameworks'),
      thClass: 'md:gl-max-w-26 !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: true,
    },
    {
      key: 'requirements',
      label: __('Requirements'),
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'associatedProjects',
      label: __('Associated projects'),
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'policies',
      label: __('Policies'),
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'updatedAt',
      label: __('Last updated'),
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'md:gl-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: true,
    },
    {
      key: 'action',
      label: __('Action'),
      thAlignRight: true,
      thClass: 'md:gl-max-w-26 gl-whitespace-nowrap',
      tdClass: 'md:gl-max-w-26 !gl-text-right gl-cursor-pointer',
      sortable: false,
    },
  ],
  i18n: {
    dropdownTitle: __('Manage framework'),
    noFrameworksFound: s__('ComplianceReport|No frameworks found'),
    editTitle: s__('ComplianceFrameworks|Edit compliance framework'),
    noFrameworksText: s__(
      'ComplianceFrameworks|No frameworks found. Create a framework in top-level group',
    ),
    learnMore: __('Learn more'),
    copyIdToastText: s__('ComplianceFrameworksReport|Framework ID copied to clipboard.'),
    actionCopyId: s__('ComplianceFrameworksReport|Copy ID'),
    copyIdExplanation: s__(
      'ComplianceFrameworksReport|Use the compliance framework ID in configuration or API requests.',
    ),
    actionEdit: __('Edit'),
    actionExport: __('Export as a JSON file'),
    actionDelete: __('Delete'),
    actionSetAsDefault: __('Set as default'),
    actionRemoveAsDefault: __('Remove as default'),
    toggleText: __('Actions for'),
    deleteButtonLinkedPoliciesDisabledTooltip: s__(
      "ComplianceFrameworks|Compliance frameworks that are linked to an active policy can't be deleted",
    ),
    deleteButtonDefaultFrameworkDisabledTooltip: s__(
      "ComplianceFrameworks|The default framework can't be deleted",
    ),
    andMore: s__('ComplianceReport|and %{count} more'),
    setAsDefaultFrameworkSuccess: s__(
      'ComplianceFrameworksReport|Default framework set successfully',
    ),
    setAsDefaultFrameworkError: s__('ComplianceFrameworksReport|Failed to set default framework'),
    setAsDefaultFrameworkTooltip: s__('ComplianceFrameworksReport|Set as default framework'),
    removeAsDefaultFrameworkSuccess: s__(
      'ComplianceFrameworksReport|Default framework removed successfully',
    ),
    removeAsDefaultFrameworkError: s__(
      'ComplianceFrameworksReport|Failed to remove default framework',
    ),
    removeAsDefaultFrameworkTooltip: s__('ComplianceFrameworksReport|Remove as default framework'),
  },
  CREATE_FRAMEWORKS_DOCS_URL,
};
</script>
<template>
  <section>
    <div v-if="hasSearch" class="gl-flex gl-gap-4 gl-bg-subtle gl-p-4">
      <gl-search-box-by-click
        class="gl-grow"
        @submit="$emit('search', $event)"
        @clear="$emit('search', '')"
      />
    </div>
    <gl-alert
      v-if="showNoFrameworksAlert"
      variant="info"
      data-testid="no-frameworks-alert"
      :dismissible="false"
    >
      <div>
        {{ $options.i18n.noFrameworksText }}
        <gl-link :href="rootAncestor.complianceCenterPath"> {{ rootAncestor.name }}</gl-link
        >.
        <gl-link :href="$options.CREATE_FRAMEWORKS_DOCS_URL"
          >{{ $options.i18n.learnMore }}.</gl-link
        >
      </div>
    </gl-alert>
    <gl-table
      :fields="tableFields"
      :busy="isLoading"
      :items="frameworks"
      no-local-sorting
      show-empty
      stacked="md"
      hover
      @row-clicked="toggleDrawer"
      @sort-changed="$emit('sortChanged', $event)"
    >
      <template #cell(name)="{ item }">
        <framework-badge :framework="item" :popover-mode="isTopLevelGroup ? 'edit' : 'details'" />
      </template>
      <template #cell(requirements)="{ item: { complianceRequirements: requirements } }">
        <div
          v-for="(requirement, index) in requirements.nodes.slice(0, policyDisplayLimit)"
          :key="requirement.id"
          class="gl-inline-block"
          data-testid="requirement-item"
        >
          {{ requirement.name
          }}<span v-if="index < lastVisiblePolicyIndex(requirements.nodes)">,&nbsp;</span>
        </div>
        <template v-if="remainingRequirementsCount(requirements) > 0">
          <gl-sprintf :message="$options.i18n.andMore">
            <template #count>{{ remainingRequirementsCount(requirements) }}</template>
          </gl-sprintf>
        </template>
      </template>
      <template #cell(associatedProjects)="{ item: { projects } }">
        <div
          v-for="(associatedProject, index) in projects.nodes"
          :key="associatedProject.id"
          class="gl-inline-block"
        >
          <gl-link :href="associatedProject.webUrl">{{ associatedProject.name }}</gl-link
          ><span v-if="!isLastItem(index, projects.nodes)">,&nbsp;</span>
        </div>
        <template v-if="projects.pageInfo.hasNextPage">
          <gl-sprintf :message="$options.i18n.andMore">
            <template #count>{{ remainingProjectsCount(projects) }}</template>
          </gl-sprintf>
        </template>
      </template>
      <template #cell(policies)="{ item }">
        {{ getPoliciesList(item) }}
      </template>
      <template #cell(updatedAt)="{ item }">
        <time-ago :time="item.updatedAt" />
      </template>
      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
      <template #cell(action)="{ item }">
        <gl-disclosure-dropdown
          :ref="`framework-dropdown-${item.id}`"
          icon="ellipsis_v"
          :toggle-text="`${$options.i18n.toggleText} ${item.name}`"
          text-sr-only
          category="tertiary"
          placement="bottom-end"
          no-caret
        >
          <template #header>
            <div class="gl-border-b gl-border-b-dropdown gl-p-4 gl-text-left">
              <span class="gl-font-bold">
                {{ $options.i18n.dropdownTitle }}
              </span>
            </div>
          </template>
          <template v-if="!isTopLevelGroup">
            <div class="gl-mx-2">
              <gl-button
                v-gl-tooltip.left.viewport
                data-testid="action-copy-id"
                :title="$options.i18n.copyIdExplanation"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="copyFrameworkId(item.id)"
              >
                {{ $options.i18n.actionCopyId }}: {{ getIdFromGraphQLId(item.id) }}
              </gl-button>
            </div>
          </template>
          <template v-if="isTopLevelGroup">
            <div class="gl-mx-2">
              <gl-button
                v-if="isTopLevelGroup"
                data-testid="action-edit"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="editFramework({ id: item.id })"
              >
                {{ $options.i18n.actionEdit }}
              </gl-button>
            </div>
            <div
              v-if="isTopLevelGroup"
              v-gl-tooltip.left.viewport
              class="gl-mx-2"
              data-testid="set-as-default-tooltip"
              :title="getSetAsDefaultActionTooltipTitle(item)"
            >
              <gl-button
                data-testid="action-set-as-default"
                class="!gl-justify-start !gl-border-none"
                category="tertiary"
                :block="true"
                @click="updateDefaultFramework({ framework: item, isDefault: !item.default })"
              >
                {{
                  item.default
                    ? $options.i18n.actionRemoveAsDefault
                    : $options.i18n.actionSetAsDefault
                }}
              </gl-button>
            </div>
            <div class="gl-mx-2">
              <gl-button
                v-gl-tooltip.left.viewport
                data-testid="action-copy-id"
                :title="$options.i18n.copyIdExplanation"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="copyFrameworkId(item.id)"
              >
                {{ $options.i18n.actionCopyId }}: {{ getIdFromGraphQLId(item.id) }}
              </gl-button>
            </div>
            <div v-if="isTopLevelGroup" class="gl-mx-2">
              <gl-button
                data-testid="action-export"
                class="!gl-justify-start"
                category="tertiary"
                :block="true"
                @click="exportFramework(item)"
              >
                {{ $options.i18n.actionExport }}
              </gl-button>
            </div>
            <div
              v-if="isTopLevelGroup"
              v-gl-tooltip.left.viewport
              class="gl-mx-2"
              data-testid="delete-tooltip"
              :title="getDeleteActionTooltipTitle(item)"
            >
              <gl-button
                data-testid="action-delete"
                class="!gl-justify-start !gl-border-none"
                category="tertiary"
                :block="true"
                :disabled="shouldDisableDeleteAction(item)"
                @click="showDeleteModal(item)"
              >
                {{ $options.i18n.actionDelete }}
              </gl-button>
            </div>
          </template>
        </gl-disclosure-dropdown>
      </template>
      <template #empty>
        <div class="gl-my-5 gl-text-center">
          {{ $options.i18n.noFrameworksFound }}
        </div>
      </template>
    </gl-table>
    <framework-info-drawer
      :group-path="groupPath"
      :root-ancestor="rootAncestor"
      :framework="selectedFramework"
      @close="closeDrawer"
      @edit="editFramework"
    />
    <delete-modal
      ref="deleteModal"
      :name="frameworkToDeleteName || ''"
      @delete="$emit('delete-framework', frameworkToDeleteId)"
    />
  </section>
</template>
