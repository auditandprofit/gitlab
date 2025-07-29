<script>
import {
  DEFAULT_PROJECT_TEXT,
  SCOPE_TITLE,
} from 'ee/security_orchestration/components/policy_drawer/constants';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope_default_label.vue';
import {
  policyScopeHasComplianceFrameworks,
  policyScopeHasExcludingProjects,
  policyScopeHasIncludingProjects,
  policyScopeHasGroups,
  policyScopeProjects,
  policyScopeGroups,
  policyExcludingProjects,
  policyScopeComplianceFrameworks,
  isGroup,
  isProject,
} from 'ee/security_orchestration/components/utils';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import LoaderWithMessage from '../loader_with_message.vue';
import ComplianceFrameworksToggleList from './compliance_frameworks_toggle_list.vue';
import ProjectsToggleList from './projects_toggle_list.vue';
import GroupsToggleList from './groups_toggle_list.vue';
import InfoRow from './info_row.vue';

export default {
  name: 'ScopeInfoRow',
  components: {
    ComplianceFrameworksToggleList,
    InfoRow,
    LoaderWithMessage,
    ProjectsToggleList,
    GroupsToggleList,
    ScopeDefaultLabel,
  },
  i18n: {
    scopeTitle: SCOPE_TITLE,
    defaultProjectText: DEFAULT_PROJECT_TEXT,
  },
  inject: ['namespaceType', 'namespacePath'],
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const {
          securityPolicyProjectLinkedProjects: { nodes: linkedProjects = [] } = {},
          securityPolicyProjectLinkedGroups: { nodes: linkedGroups = [] } = {},
        } = data?.project || {};

        return [...linkedProjects, ...linkedGroups];
      },
      skip() {
        return this.isGroup;
      },
      error() {
        this.$emit('linked-spp-query-error');
      },
    },
  },
  props: {
    isInstanceLevel: {
      type: Boolean,
      required: false,
      default: false,
    },
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      linkedSppItems: [],
    };
  },
  computed: {
    isGroup() {
      return isGroup(this.namespaceType);
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    showScopeSection() {
      return this.isGroup || this.hasMultipleProjectsLinked;
    },
    policyScopeHasComplianceFrameworks() {
      return policyScopeHasComplianceFrameworks(this.policyScope) && this.showScopeSection;
    },
    policyScopeHasIncludingProjects() {
      return policyScopeHasIncludingProjects(this.policyScope);
    },
    policyScopeHasGroups() {
      return policyScopeHasGroups(this.policyScope) && this.showScopeSection;
    },
    policyScopeHasExcludingProjects() {
      return policyScopeHasExcludingProjects(this.policyScope);
    },
    policyHasProjects() {
      return (
        (this.policyScopeHasIncludingProjects || this.policyScopeHasExcludingProjects) &&
        this.showScopeSection
      );
    },
    policyScopeGroups() {
      return policyScopeGroups(this.policyScope);
    },
    policyScopeProjects() {
      return policyScopeProjects(this.policyScope);
    },
    policyExcludingProjects() {
      return policyExcludingProjects(this.policyScope);
    },
    policyScopeComplianceFrameworks() {
      return policyScopeComplianceFrameworks(this.policyScope);
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    showDefaultText() {
      return this.isProject && !this.hasMultipleProjectsLinked;
    },
    showLoader() {
      return this.$apollo.queries.linkedSppItems?.loading && this.isProject;
    },
  },
};
</script>

<template>
  <info-row :label="$options.i18n.scopeTitle" data-testid="policy-scope">
    <loader-with-message v-if="showLoader" />
    <template v-else>
      <p v-if="showDefaultText" class="gl-m-0" data-testid="default-project-text">
        {{ $options.i18n.defaultProjectText }}
      </p>
      <div v-else class="gl-inline-flex gl-flex-wrap gl-gap-3">
        <template v-if="policyScopeHasComplianceFrameworks">
          <compliance-frameworks-toggle-list
            :compliance-frameworks="policyScopeComplianceFrameworks"
          />
        </template>
        <template v-else-if="policyScopeHasGroups">
          <groups-toggle-list
            is-link
            :groups="policyScopeGroups"
            :projects="policyExcludingProjects"
          />
        </template>
        <template v-else-if="policyHasProjects">
          <projects-toggle-list
            :is-group="isGroup"
            :is-instance-level="isInstanceLevel"
            :including="policyScopeHasIncludingProjects"
            :projects="policyScopeProjects.projects"
          />
        </template>
        <div v-else data-testid="default-scope-text">
          <scope-default-label
            :is-group="isGroup"
            :policy-scope="policyScope"
            :linked-items="linkedSppItems"
          />
        </div>
      </div>
    </template>
  </info-row>
</template>
