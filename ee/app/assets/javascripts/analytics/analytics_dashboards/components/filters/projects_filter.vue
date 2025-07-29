<script>
import ProjectsDropdownFilter from '~/analytics/shared/components/projects_dropdown_filter.vue';
import { getParameterByName } from '~/lib/utils/url_utility';
import GetDefaultProjectQuery from './get_default_project.query.graphql';
import { PROJECT_FILTER_QUERY_NAME } from './constants';

export default {
  components: {
    ProjectsDropdownFilter,
  },
  props: {
    groupNamespace: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      defaultProject: null,
    };
  },
  apollo: {
    defaultProject: {
      query: GetDefaultProjectQuery,
      variables() {
        return { fullPath: this.defaultProjectPath };
      },
      update({ project }) {
        return project;
      },
      skip() {
        return !this.defaultProjectPath;
      },
    },
  },
  computed: {
    defaultProjectPath() {
      return getParameterByName(PROJECT_FILTER_QUERY_NAME);
    },
    queryParams() {
      return {
        first: 50,
        includeSubgroups: true,
      };
    },
    isLoadingDefaultProject() {
      return this.$apollo.queries.defaultProject.loading;
    },
    defaultProjects() {
      return this.defaultProject ? [this.defaultProject] : [];
    },
  },
  methods: {
    onProjectsSelected(selectedProjects) {
      this.$emit('projectSelected', selectedProjects[0] || null);
    },
  },
};
</script>

<template>
  <projects-dropdown-filter
    :key="groupNamespace"
    toggle-classes="gl-max-w-26"
    :query-params="queryParams"
    :group-namespace="groupNamespace"
    :use-graphql="true"
    :loading-default-projects="isLoadingDefaultProject"
    :default-projects="defaultProjects"
    @selected="onProjectsSelected"
  />
</template>
