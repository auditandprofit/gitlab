<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { s__ } from '~/locale';
import {
  EXCEPT_PROJECTS,
  EXCLUDING,
  INCLUDING,
  WITHOUT_EXCEPTIONS,
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  EXCEPTION_TYPE_TEXTS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import InstanceProjectsDropdown from 'ee/security_orchestration/components/shared/instance_projects_dropdown.vue';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';

export default {
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  i18n: {
    groupProjectErrorDescription: s__('SecurityOrchestration|Failed to load group projects'),
  },
  name: 'ScopeProjectSelector',
  components: {
    GlCollapsibleListbox,
    GroupProjectsDropdown,
    InstanceProjectsDropdown,
  },
  inject: ['designatedAsCsp'],
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    projects: {
      type: Object,
      required: true,
      default: () => ({}),
    },
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
    exceptionType: {
      type: String,
      required: false,
      default: WITHOUT_EXCEPTIONS,
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    payloadKey() {
      return this.showExceptions ? EXCLUDING : INCLUDING;
    },
    showExceptions() {
      return Boolean(this.projects?.excluding) || isEmpty(this.projects);
    },
    projectIds() {
      /**
       * Protection from manual yaml input as objects
       * return Array of objects with mapped to GraphQl format ids
       */
      const projects = Array.isArray(this.projects?.[this.payloadKey])
        ? this.projects?.[this.payloadKey]
        : [];

      const projectIds = projects?.map(({ id }) => id) || [];

      if (this.designatedAsCsp) {
        return projectIds;
      }

      // Non-CSP project selector uses graphql
      return projectIds.map((id) => convertToGraphQLId(TYPENAME_PROJECT, id));
    },
    selectedExceptionTypeText() {
      return EXCEPTION_TYPE_TEXTS[this.exceptionType];
    },
    showProjectsDropdown() {
      return this.exceptionType === EXCEPT_PROJECTS || !this.showExceptions;
    },
    projectsEmpty() {
      return this.projectIds.length === 0;
    },
    isFieldValid() {
      return !this.projectsEmpty || !this.isDirty;
    },
  },
  methods: {
    emitError() {
      this.$emit('error', this.$options.i18n.groupProjectErrorDescription);
    },
    selectExceptionType(type) {
      if (type === WITHOUT_EXCEPTIONS) {
        this.$emit('changed', { projects: { [this.payloadKey]: [] } });
      }

      this.$emit('select-exception-type', type);
    },
    setSelectedProjects(projects) {
      const projectsIds = projects.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));
      const payload = { projects: { [this.payloadKey]: projectsIds } };
      this.$emit('changed', payload);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-gap-3">
    <gl-collapsible-listbox
      v-if="showExceptions"
      data-testid="exception-type"
      :disabled="disabled"
      :items="$options.EXCEPTION_TYPE_LISTBOX_ITEMS"
      :toggle-text="selectedExceptionTypeText"
      :selected="exceptionType"
      @select="selectExceptionType"
    />

    <template v-if="showProjectsDropdown">
      <instance-projects-dropdown
        v-if="designatedAsCsp"
        :disabled="disabled"
        :selected="projectIds"
        :state="isFieldValid"
        @projects-query-error="emitError"
        @select="setSelectedProjects"
      />

      <group-projects-dropdown
        v-else
        :disabled="disabled"
        :group-full-path="groupFullPath"
        :selected="projectIds"
        :state="isFieldValid"
        @projects-query-error="emitError"
        @select="setSelectedProjects"
      />
    </template>
  </div>
</template>
