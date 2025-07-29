<script>
import {
  GlButton,
  GlDropdown,
  GlDropdownDivider,
  GlDropdownSectionHeader,
  GlDropdownItem,
  GlFormInput,
  GlSearchBoxByType,
  GlLoadingIcon,
} from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { debounce } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';

import Api from '~/api';
import { createAlert } from '~/alert';
import { STORAGE_KEY } from '~/super_sidebar/constants';
import { getTopFrequentItems } from '~/super_sidebar/utils';
import AccessorUtilities from '~/lib/utils/accessor';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __ } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import { SEARCH_DEBOUNCE, MAX_FREQUENT_PROJECTS } from '../constants';

export default {
  components: {
    GlButton,
    GlDropdown,
    GlDropdownItem,
    GlDropdownSectionHeader,
    GlDropdownDivider,
    GlFormInput,
    GlSearchBoxByType,
    GlLoadingIcon,
    ProjectAvatar,
  },
  data() {
    return {
      frequentProjects: [],
      selectedProject: null,
      searchKey: '',
      title: '',
      frequentProjectFetchInProgress: false,
    };
  },
  computed: {
    ...mapState([
      'projectsFetchInProgress',
      'itemCreateInProgress',
      'projects',
      'parentItem',
      'defaultProjectForIssueCreation',
    ]),
    dropdownToggleText() {
      if (this.selectedProject) {
        /** When selectedProject is fetched from localStorage
         * name_with_namespace doesn't exist. Therefore we rely on
         * namespace directly.
         * */
        return this.selectedProject.name_with_namespace || this.selectedProject.namespace;
      }

      return __('Select a project');
    },
    isIssueCreationDisabled() {
      return !this.selectedProject || this.itemCreateInProgress || !this.title;
    },
  },

  watch: {
    /**
     * We're using `debounce` here as `GlSearchBoxByType` doesn't
     * support `lazy` or `debounce` props as per https://bootstrap-vue.js.org/docs/components/form-input/.
     * This is a known GitLab UI issue https://gitlab.com/gitlab-org/gitlab-ui/-/issues/631 [CLOSED]
     */
    searchKey: debounce(function debounceSearch() {
      this.fetchProjects(this.searchKey);
      this.setFrequentProjects(this.searchKey);
    }, SEARCH_DEBOUNCE),
    /**
     * As Issue Create Form already has `autofocus` set for
     * Issue title field, we cannot leverage `autofocus` prop
     * again for search input field, so we manually set
     * focus only when dropdown is opened and content is loaded.
     */
    projectsFetchInProgress(value) {
      if (!value) {
        this.$nextTick(() => {
          this.$refs.searchInputField.focusInput();
        });
      }
    },
  },
  mounted() {
    this.selectedProject = this.dataForDefaultProject(this.defaultProjectForIssueCreation);
  },
  methods: {
    ...mapActions(['fetchProjects']),
    cancel() {
      this.$emit('cancel');
    },
    dataForDefaultProject(defaultProject) {
      if (!defaultProject) {
        return null;
      }

      const { id: globalId, nameWithNamespace } = defaultProject;

      return {
        id: getIdFromGraphQLId(globalId),
        namespace: nameWithNamespace,
      };
    },
    createIssue() {
      if (this.isIssueCreationDisabled) {
        return;
      }

      const { selectedProject, title } = this;
      const url = Api.buildUrl(Api.projectCreateIssuePath).replace(
        ':id',
        encodeURIComponent(selectedProject.id),
      );

      this.$emit('submit', { issuesEndpoint: url, title });
      this.resetForm();
    },
    resetForm() {
      /**
       * We do not reset the selected project as it's common to create multiple
       * issues in one project at once.
       */
      this.title = '';
    },
    handleDropdownShow() {
      this.searchKey = '';
      this.setFrequentProjects();
      this.fetchProjects();
    },
    handleFrequentProjectSelection(selectedProject) {
      this.frequentProjectFetchInProgress = true;
      this.selectedProject = selectedProject;

      Api.project(selectedProject.id)
        .then((res) => res.data)
        .then((data) => {
          this.selectedProject = data;
        })
        .catch(() => {
          createAlert({
            message: __('Something went wrong while fetching details'),
          });
          this.selectedProject = null;
        })
        .finally(() => {
          this.frequentProjectFetchInProgress = false;
        });
    },
    setFrequentProjects(searchTerm) {
      const { current_username: currentUsername } = gon;

      if (!currentUsername) {
        return [];
      }

      const storageKey = `${currentUsername}/${STORAGE_KEY.projects}`;

      if (!AccessorUtilities.canUseLocalStorage()) {
        return [];
      }

      const storedRawItems = localStorage.getItem(storageKey);

      let storedFrequentProjects = storedRawItems ? JSON.parse(storedRawItems) : [];

      /* Filter for the current group */
      storedFrequentProjects = storedFrequentProjects.filter((item) => {
        return Boolean(item.webUrl?.slice(1)?.startsWith(this.parentItem.fullPath));
      });

      if (searchTerm) {
        storedFrequentProjects = fuzzaldrinPlus.filter(storedFrequentProjects, searchTerm, {
          key: ['namespace'],
        });
      }

      this.frequentProjects = getTopFrequentItems(
        storedFrequentProjects,
        MAX_FREQUENT_PROJECTS,
      ).map((item) => {
        return { ...item, avatar_url: item.avatarUrl, web_url: item.webUrl };
      });

      return this.frequentProjects;
    },
  },
};
</script>

<template>
  <form data-testid="form" @submit.prevent="createIssue">
    <div class="row mb-3">
      <div class="col-sm-6 gl-mb-3 sm:gl-mb-0">
        <label class="label-bold">{{ s__('Issue|Title') }}</label>
        <gl-form-input
          ref="titleInput"
          v-model.trim="title"
          data-testid="title-input"
          :placeholder="
            parentItem.confidential ? __('New confidential issue title') : __('New issue title')
          "
          autofocus
        />
      </div>
      <div class="col-sm-6">
        <label class="label-bold">{{ __('Project') }}</label>
        <gl-dropdown
          ref="dropdownButton"
          :text="dropdownToggleText"
          class="projects-dropdown gl-w-full"
          menu-class="!gl-w-full !gl-overflow-hidden"
          toggle-class="gl-flex gl-items-center gl-justify-content-between gl-truncate"
          @show="handleDropdownShow"
        >
          <gl-search-box-by-type
            ref="searchInputField"
            v-model="searchKey"
            class="gl-mx-3 gl-mb-2"
            :disabled="projectsFetchInProgress"
          />
          <div class="dropdown-contents gl-overflow-auto gl-pb-2">
            <gl-dropdown-section-header v-if="frequentProjects.length > 0">{{
              __('Recently used')
            }}</gl-dropdown-section-header>

            <div v-if="frequentProjects.length > 0" data-testid="frequent-items-content">
              <gl-dropdown-item
                v-for="project in frequentProjects"
                :key="`frequent-${project.id}`"
                class="select-project-dropdown gl-w-full"
                @click="() => handleFrequentProjectSelection(project)"
              >
                <div class="gl-flex">
                  <project-avatar
                    :project-id="project.id"
                    :project-avatar-url="project.avatar_url"
                    :project-name="project.name"
                  />
                  <span
                    ><span class="block">{{ project.name }}</span>
                    <span class="block gl-text-subtle">{{ project.namespace }}</span></span
                  >
                </div>
              </gl-dropdown-item>
            </div>

            <gl-dropdown-divider v-if="frequentProjects.length > 0" />
            <template v-if="!projectsFetchInProgress">
              <span v-if="!projects.length" class="text-center gl-block gl-p-3">{{
                __('No matches found')
              }}</span>
              <gl-dropdown-item
                v-for="project in projects"
                :key="project.id"
                :data-testid="`project-item-${project.id}`"
                class="select-project-dropdown gl-w-full"
                @click="selectedProject = project"
              >
                <div class="gl-flex">
                  <project-avatar
                    :project-id="project.id"
                    :project-avatar-url="project.avatar_url"
                    :project-name="project.name"
                  />
                  <span
                    ><span class="block">{{ project.name }}</span>
                    <span class="block gl-text-subtle">{{ project.namespace.name }}</span></span
                  >
                </div>
              </gl-dropdown-item>
            </template>
          </div>
          <gl-loading-icon
            v-show="projectsFetchInProgress"
            class="projects-fetch-loading gl-items-center gl-p-3"
            size="lg"
          />
        </gl-dropdown>
      </div>
    </div>

    <div>
      <gl-button
        variant="confirm"
        category="primary"
        size="small"
        type="submit"
        class="gl-mr-2"
        data-testid="submit-button"
        :disabled="isIssueCreationDisabled"
        :loading="itemCreateInProgress || frequentProjectFetchInProgress"
        @click="createIssue"
        >{{ __('Create issue') }}</gl-button
      >
      <gl-button size="small" data-testId="cancel-btn" @click="cancel">{{
        __('Cancel')
      }}</gl-button>
    </div>
  </form>
</template>
