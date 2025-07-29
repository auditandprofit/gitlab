<script>
import { isEmpty } from 'lodash';
import {
  GlAlert,
  GlCollapsibleListbox,
  GlFormCheckbox,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { isProject, isGroup } from 'ee/security_orchestration/components/utils';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import LoaderWithMessage from '../../loader_with_message.vue';
import ComplianceFrameworkDropdown from './compliance_framework_dropdown.vue';
import ScopeSectionAlert from './scope_section_alert.vue';
import ScopeGroupSelector from './scope_group_selector.vue';
import ScopeProjectSelector from './scope_project_selector.vue';
import {
  CSP_SCOPE_TYPE_LISTBOX_ITEMS,
  CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS,
  CSP_SCOPE_TYPE_TEXTS,
  PROJECTS_WITH_FRAMEWORK,
  PROJECT_SCOPE_TYPE_LISTBOX_ITEMS,
  PROJECT_SCOPE_TYPE_TEXTS,
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  WITHOUT_EXCEPTIONS,
  SPECIFIC_PROJECTS,
  EXCEPT_PROJECTS,
  ALL_PROJECTS_IN_GROUP,
  INCLUDING,
  EXCLUDING,
  COMPLIANCE_FRAMEWORKS_KEY,
  PROJECTS_KEY,
  ALL_PROJECTS_IN_LINKED_GROUPS,
  GROUPS_KEY,
} from './constants';

export default {
  COMPLIANCE_FRAMEWORK_PATH: helpPagePath('user/group/compliance_frameworks.md'),
  SCOPE_HELP_PATH: helpPagePath('user/application_security/policies/_index.md'),
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  i18n: {
    policyScopeLoadingText: s__('SecurityOrchestration|Fetching the scope information.'),
    policyScopeErrorText: s__(
      'SecurityOrchestration|Failed to fetch the scope information. Please refresh the page to try again.',
    ),
    policyScopeFrameworkCopyProject: s__(
      'SecurityOrchestration|Apply this policy to current project.',
    ),
    defaultModeTitle: s__('SecurityOrchestration|Use default mode for scoping'),
    defaultModeDescription: s__(
      'SecurityOrchestration|Enforce policy on all groups, subgroups, and projects linked to the security policy project. %{linkStart}How does scoping work?%{linkEnd}',
    ),
    defaultModePopover: s__('SecurityOrchestration|Turn off default mode to edit scope.'),
    policyScopeFrameworkCopy: s__(
      `SecurityOrchestration|Apply this policy to %{projectScopeType}named %{frameworkSelector}`,
    ),
    policyScopeProjectCopy: s__(
      `SecurityOrchestration|Apply this policy to %{projectScopeType} %{projectSelector}`,
    ),
    groupProjectErrorDescription: s__('SecurityOrchestration|Failed to load group projects'),
    complianceFrameworkErrorDescription: s__(
      'SecurityOrchestration|Failed to load compliance frameworks',
    ),
    complianceFrameworkPopoverTitle: __('Information'),
    complianceFrameworkPopoverContent: s__(
      'SecurityOrchestration|A compliance framework is a label to identify that your project has certain compliance requirements. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  name: 'ScopeSection',
  components: {
    ComplianceFrameworkDropdown,
    GlAlert,
    GlCollapsibleListbox,
    GlFormCheckbox,
    GlIcon,
    GlLink,
    GlSprintf,
    LoaderWithMessage,
    PolicyPopover,
    ScopeSectionAlert,
    ScopeGroupSelector,
    ScopeProjectSelector,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const linkedProjects = data?.project?.securityPolicyProjectLinkedProjects?.nodes || [];
        const linkedGroups = data?.project?.securityPolicyProjectLinkedGroups?.nodes || [];

        const items = [...linkedProjects, ...linkedGroups];

        if (
          isEmpty(this.policyScope) &&
          items.length > 1 &&
          !this.isGroupLevel &&
          !this.hasExistingPolicy
        ) {
          this.setDefaultScope();
        }

        return items;
      },
      error() {
        this.showLinkedSppItemsError = true;
      },
      skip() {
        return this.isGroupLevel;
      },
    },
  },
  inject: [
    'assignedPolicyProject',
    'designatedAsCsp',
    'existingPolicy',
    'namespacePath',
    'namespaceType',
    'rootNamespacePath',
  ],
  props: {
    policyScope: {
      type: Object,
      required: true,
      default: () => ({}),
    },
  },
  data() {
    let selectedProjectScopeType = ALL_PROJECTS_IN_GROUP;
    let selectedExceptionType = WITHOUT_EXCEPTIONS;
    let projectsPayloadKey = EXCLUDING;

    const { projects = [] } = this.policyScope || {};
    const { groups = [] } = this.policyScope || {};

    if (projects?.excluding && projects.excluding.length > 0) {
      selectedExceptionType = EXCEPT_PROJECTS;
    }

    if (this.policyScope?.compliance_frameworks) {
      selectedProjectScopeType = PROJECTS_WITH_FRAMEWORK;
    }

    if (groups.including) {
      selectedProjectScopeType = ALL_PROJECTS_IN_LINKED_GROUPS;
    }

    if (projects?.including && !groups.including?.length) {
      selectedProjectScopeType = SPECIFIC_PROJECTS;
      projectsPayloadKey = INCLUDING;
    }

    return {
      useDefaultScope: isEmpty(this.policyScope),
      selectedProjectScopeType,
      selectedExceptionType,
      projectsPayloadKey,
      showAlert: false,
      errorDescription: '',
      linkedSppItems: [],
      showLinkedSppItemsError: false,
      isFormDirty: false,
    };
  },
  computed: {
    assignedPolicyProjectPath() {
      return this.isGroupLevel ? this.assignedPolicyProject?.fullPath || '' : this.namespacePath;
    },
    hasGroups() {
      return Boolean(this.policyScope.groups?.including);
    },
    showScopeGroupSelector() {
      return this.hasGroups || this.selectedProjectScopeType === ALL_PROJECTS_IN_LINKED_GROUPS;
    },
    hasExistingPolicy() {
      return Boolean(this.existingPolicy);
    },
    isGroupLevel() {
      return isGroup(this.namespaceType);
    },
    isProjectLevel() {
      return isProject(this.namespaceType);
    },
    isAllProjects() {
      return this.selectedProjectScopeType === ALL_PROJECTS_IN_GROUP;
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    disableScopeSelector() {
      return (
        this.isProjectLevel &&
        this.hasMultipleProjectsLinked &&
        this.hasExistingPolicy &&
        this.useDefaultScope
      );
    },
    showDefaultScopeSelector() {
      return this.isProjectLevel && this.hasExistingPolicy;
    },
    groups() {
      return this.policyScope?.groups || {};
    },
    projects() {
      return this.policyScope?.projects || {};
    },
    projectIds() {
      /**
       * Protection from manual yam input as objects
       * @type {*|*[]}
       */
      const projects = Array.isArray(this.policyScope?.projects?.[this.projectsPayloadKey])
        ? this.policyScope?.projects?.[this.projectsPayloadKey]
        : [];

      return projects?.map(({ id }) => convertToGraphQLId(TYPENAME_PROJECT, id)) || [];
    },
    groupIds() {
      return this.policyScope?.groups?.including || [];
    },
    complianceFrameworksIds() {
      /**
       * Protection from manual yam input as objects
       * @type {*|*[]}
       */
      const frameworks = Array.isArray(this.policyScope?.compliance_frameworks)
        ? this.policyScope?.compliance_frameworks
        : [];
      return frameworks?.map(({ id }) => id) || [];
    },
    selectedProjectScopeText() {
      return this.designatedAsCsp
        ? CSP_SCOPE_TYPE_TEXTS[this.selectedProjectScopeType]
        : PROJECT_SCOPE_TYPE_TEXTS[this.selectedProjectScopeType];
    },
    showScopeSelector() {
      return this.isGroupLevel || this.hasMultipleProjectsLinked;
    },
    showExceptionTypeDropdown() {
      return this.isAllProjects;
    },
    showGroupProjectsDropdown() {
      return (
        (this.showExceptionTypeDropdown && this.selectedExceptionType === EXCEPT_PROJECTS) ||
        this.selectedProjectScopeType === SPECIFIC_PROJECTS ||
        this.isAllProjects
      );
    },
    payloadKey() {
      if ([ALL_PROJECTS_IN_GROUP, SPECIFIC_PROJECTS].includes(this.selectedProjectScopeType)) {
        return PROJECTS_KEY;
      }

      if (this.selectedProjectScopeType === ALL_PROJECTS_IN_LINKED_GROUPS) {
        return GROUPS_KEY;
      }

      return COMPLIANCE_FRAMEWORKS_KEY;
    },
    policyScopeCopy() {
      return this.selectedProjectScopeType === PROJECTS_WITH_FRAMEWORK
        ? this.$options.i18n.policyScopeFrameworkCopy
        : this.$options.i18n.policyScopeProjectCopy;
    },
    showLoader() {
      return this.$apollo.queries.linkedSppItems?.loading && !this.isGroupLevel;
    },
    isProjectsWithoutExceptions() {
      return this.selectedExceptionType === WITHOUT_EXCEPTIONS;
    },
    projectsEmpty() {
      return this.projectIds.length === 0;
    },
    groupsEmpty() {
      return this.groupIds.length === 0;
    },
    complianceFrameworksEmpty() {
      return this.complianceFrameworksIds.length === 0;
    },
    complianceFrameworksValidState() {
      return this.complianceFrameworksEmpty && this.isFormDirty;
    },
    scopeDropdownItems() {
      // Non-CSP projects use standard project scope items
      if (!this.designatedAsCsp) {
        return PROJECT_SCOPE_TYPE_LISTBOX_ITEMS;
      }

      // CSP with groups: show all options
      if (this.hasGroups) {
        return CSP_SCOPE_TYPE_LISTBOX_ITEMS;
      }

      // CSP without groups: exclude "all projects in linked groups" option
      return CSP_SCOPE_TYPE_WITHOUT_GROUP_LISTBOX_ITEMS;
    },
  },
  methods: {
    resetPolicyScope() {
      const internalPayload =
        this.payloadKey === COMPLIANCE_FRAMEWORKS_KEY ? [] : { [this.projectsPayloadKey]: [] };
      const payload = {
        [this.payloadKey]: internalPayload,
      };

      this.$emit('changed', payload);
    },
    selectProjectScopeType(scopeType) {
      this.isFormDirty = false;

      this.selectedProjectScopeType = scopeType;
      this.projectsPayloadKey = this.isAllProjects ? EXCLUDING : INCLUDING;
      this.resetPolicyScope();
    },
    selectExceptionType(type) {
      this.isFormDirty = false;

      this.selectedExceptionType = type;
    },
    setSelectedItems(payload) {
      this.isFormDirty = true;
      this.triggerChanged(payload);
    },
    setSelectedFrameworkIds(ids) {
      this.isFormDirty = true;

      const payload = ids.map((id) => ({ id }));
      this.triggerChanged({ compliance_frameworks: payload });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.policyScope, ...value });
    },
    setShowAlert(errorDescription) {
      this.showAlert = true;
      this.errorDescription = errorDescription;
    },
    setDefaultScope() {
      this.triggerChanged({ projects: { excluding: [] } });
    },
    setDefaultSelectorValues() {
      this.selectedProjectScopeType = ALL_PROJECTS_IN_GROUP;
      this.selectedExceptionType = WITHOUT_EXCEPTIONS;
      this.projectsPayloadKey = EXCLUDING;
    },
    updateScopeSelection(value) {
      if (value) {
        this.$emit('remove');
        this.setDefaultSelectorValues();
      } else {
        this.setDefaultScope();
      }
    },
  },
};
</script>

<template>
  <div>
    <scope-section-alert
      :compliance-frameworks-empty="complianceFrameworksEmpty"
      :is-dirty="isFormDirty"
      :is-projects-without-exceptions="isProjectsWithoutExceptions"
      :project-scope-type="selectedProjectScopeType"
      :project-empty="projectsEmpty"
      :groups-empty="groupsEmpty"
    />

    <gl-alert v-if="showAlert" class="gl-mb-5" variant="danger" :dismissible="false">
      {{ errorDescription }}
    </gl-alert>

    <loader-with-message v-if="showLoader" />

    <div v-else class="gl-mt-2 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <template v-if="showLinkedSppItemsError">
        <div data-testid="policy-scope-project-error" class="gl-flex gl-items-center gl-gap-3">
          <gl-icon name="status_warning" variant="danger" />
          <p data-testid="policy-scope-project-error-text" class="gl-m-0 gl-text-danger">
            {{ $options.i18n.policyScopeErrorText }}
          </p>
        </div>
      </template>

      <template v-else-if="showScopeSelector">
        <div
          :class="{ 'gl-text-disabled': disableScopeSelector }"
          class="gl-flex gl-flex-wrap gl-items-center gl-gap-3"
        >
          <gl-sprintf :message="policyScopeCopy">
            <template #projectScopeType>
              <gl-collapsible-listbox
                id="project-scope-type"
                v-gl-tooltip="{
                  title: $options.i18n.defaultModePopover,
                  disabled: !disableScopeSelector,
                }"
                fluid-width
                data-testid="project-scope-type"
                :items="scopeDropdownItems"
                :selected="selectedProjectScopeType"
                :toggle-text="selectedProjectScopeText"
                :disabled="disableScopeSelector"
                @select="selectProjectScopeType"
              />
            </template>

            <template #frameworkSelector>
              <div class="gl-inline-flex gl-flex-wrap gl-items-center gl-gap-3">
                <compliance-framework-dropdown
                  :disabled="disableScopeSelector"
                  :selected-framework-ids="complianceFrameworksIds"
                  :full-path="rootNamespacePath"
                  :show-error="complianceFrameworksValidState"
                  @framework-query-error="
                    setShowAlert($options.i18n.complianceFrameworkErrorDescription)
                  "
                  @select="setSelectedFrameworkIds"
                />

                <policy-popover
                  :content="$options.i18n.complianceFrameworkPopoverContent"
                  :href="$options.COMPLIANCE_FRAMEWORK_PATH"
                  :title="$options.i18n.complianceFrameworkPopoverTitle"
                  target="compliance-framework-icon"
                />
              </div>
            </template>

            <template #projectSelector>
              <scope-group-selector
                v-if="showScopeGroupSelector"
                class="gl-basis-full"
                :is-dirty="isFormDirty"
                :exception-type="selectedExceptionType"
                :groups="groups"
                :projects="projects"
                :disabled="disableScopeSelector"
                :full-path="assignedPolicyProjectPath"
                @select-exception-type="selectExceptionType"
                @changed="setSelectedItems"
              />
              <scope-project-selector
                v-if="showGroupProjectsDropdown"
                :disabled="disableScopeSelector"
                :is-dirty="isFormDirty"
                :exception-type="selectedExceptionType"
                :projects="projects"
                :group-full-path="rootNamespacePath"
                @error="setShowAlert($options.i18n.groupProjectErrorDescription)"
                @select-exception-type="selectExceptionType"
                @changed="setSelectedItems"
              />
            </template>
          </gl-sprintf>
        </div>
        <template v-if="showDefaultScopeSelector">
          <gl-form-checkbox
            v-model="useDefaultScope"
            class="gl-mt-3"
            data-testid="default-scope-selector"
            @change="updateScopeSelection"
          >
            {{ $options.i18n.defaultModeTitle }}
            <template #help>
              <gl-sprintf :message="$options.i18n.defaultModeDescription">
                <template #link="{ content }">
                  <gl-link :href="$options.SCOPE_HELP_PATH">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </template>
          </gl-form-checkbox>
        </template>
      </template>
      <template v-else>
        <p data-testid="policy-scope-project-text" class="gl-mb-0">
          {{ $options.i18n.policyScopeFrameworkCopyProject }}
        </p>
      </template>
    </div>
  </div>
</template>
