<script>
import ComplianceFrameworksToggleList from 'ee/security_orchestration/components/policy_drawer/compliance_frameworks_toggle_list.vue';
import ProjectsToggleList from 'ee/security_orchestration/components/policy_drawer/projects_toggle_list.vue';
import GroupsToggleList from 'ee/security_orchestration/components/policy_drawer/groups_toggle_list.vue';
import { s__ } from '~/locale';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope_default_label.vue';
import {
  policyScopeHasComplianceFrameworks,
  policyScopeComplianceFrameworks,
  policyScopeHasExcludingProjects,
  policyScopeHasIncludingProjects,
  policyScopeProjects,
  isDefaultMode,
  isGroup,
  policyScopeGroups,
  policyScopeHasGroups,
  policyExcludingProjects,
} from 'ee/security_orchestration/components/utils';

export default {
  MAX_NUMBER_OF_VISIBLE_LABELS: 2,
  i18n: {
    loaderMessage: s__('SecurityOrchestration|Fetching'),
    defaultText: s__('SecurityOrchestration|This project'),
  },
  name: 'ListComponentScope',
  components: {
    ComplianceFrameworksToggleList,
    ScopeDefaultLabel,
    GroupsToggleList,
    ProjectsToggleList,
  },
  inject: ['namespaceType'],
  props: {
    isInstanceLevel: {
      type: Boolean,
      required: false,
      default: false,
    },
    linkedSppItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    policyScope: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    isGroup() {
      return isGroup(this.namespaceType);
    },
    isDefaultMode() {
      return isDefaultMode(this.policyScope);
    },
    policyScopeComplianceFrameworks() {
      return policyScopeComplianceFrameworks(this.policyScope);
    },
    policyScopeHasIncludingProjects() {
      return policyScopeHasIncludingProjects(this.policyScope);
    },
    policyScopeProjects() {
      return policyScopeProjects(this.policyScope);
    },
    policyScopeGroups() {
      return policyScopeGroups(this.policyScope);
    },
    policyExcludingProjects() {
      return policyExcludingProjects(this.policyScope);
    },
    policyHasProjects() {
      return (
        this.policyScopeHasIncludingProjects || policyScopeHasExcludingProjects(this.policyScope)
      );
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    showScopeSection() {
      return this.isGroup || this.hasMultipleProjectsLinked;
    },
    showComplianceFrameworks() {
      return policyScopeHasComplianceFrameworks(this.policyScope) && this.showScopeSection;
    },
    showProjects() {
      return this.policyHasProjects && this.showScopeSection;
    },
    showGroups() {
      return policyScopeHasGroups(this.policyScope) && this.showScopeSection;
    },
    showDefaultLabel() {
      return this.isDefaultMode && this.showScopeSection;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-baseline gl-gap-3">
    <compliance-frameworks-toggle-list
      v-if="showComplianceFrameworks"
      :compliance-frameworks="policyScopeComplianceFrameworks"
      :labels-to-show="$options.MAX_NUMBER_OF_VISIBLE_LABELS"
    />

    <groups-toggle-list
      v-else-if="showGroups"
      inline-list
      :groups="policyScopeGroups"
      :projects="policyExcludingProjects"
    />

    <projects-toggle-list
      v-else-if="showProjects"
      inline-list
      :is-group="isGroup"
      :is-instance-level="isInstanceLevel"
      :bullet-style="false"
      :including="policyScopeHasIncludingProjects"
      :projects="policyScopeProjects.projects"
      :projects-to-show="$options.MAX_NUMBER_OF_VISIBLE_LABELS"
    />

    <scope-default-label
      v-else-if="showDefaultLabel"
      :policy-scope="policyScope"
      :is-group="isGroup"
      :linked-items="linkedSppItems"
      :items-to-show="$options.MAX_NUMBER_OF_VISIBLE_LABELS"
    />

    <p v-else class="gl-m-0" data-testid="default-text">
      {{ $options.i18n.defaultText }}
    </p>
  </div>
</template>
