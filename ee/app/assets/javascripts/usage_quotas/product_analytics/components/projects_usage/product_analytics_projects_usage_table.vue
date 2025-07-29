<script>
import { GlLink, GlSkeletonLoader, GlTableLite, GlTooltipDirective } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import {
  findCurrentMonthUsage,
  findPreviousMonthUsage,
  projectsUsageDataValidator,
} from '../utils';

export default {
  name: 'ProductAnalyticsProjectsUsageTable',
  components: {
    GlLink,
    GlSkeletonLoader,
    GlTableLite,
    ProjectAvatar,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    isLoading: {
      type: Boolean,
      required: true,
    },
    projectsUsageData: {
      type: Array,
      required: false,
      default: null,
      validator: projectsUsageDataValidator,
    },
  },
  computed: {
    hasProjects() {
      return this.projectsUsageData?.length > 0;
    },
    tableData() {
      return this.projectsUsageData.map((project) => {
        return {
          ...project,
          currentEvents: findCurrentMonthUsage(project).count,
          previousEvents: findPreviousMonthUsage(project).count,
        };
      });
    },
  },
  TABLE_FIELDS: [
    { key: 'name', label: __('Project') },
    { key: 'currentEvents', label: s__('ProductAnalytics|Current month to date') },
    { key: 'previousEvents', label: s__('ProductAnalytics|Previous month') },
  ],
};
</script>
<template>
  <div>
    <gl-skeleton-loader v-if="isLoading" :lines="3" :equal-width-lines="true" />
    <div v-else-if="hasProjects" data-testid="projects-usage-table">
      <gl-table-lite :items="tableData" :fields="$options.TABLE_FIELDS">
        <template #cell(name)="{ item: { id, name, avatarUrl, webUrl } }">
          <project-avatar
            :project-id="id"
            :project-name="name"
            :project-avatar-url="avatarUrl"
            :size="16"
            :alt="name"
            class="gl-mr-2"
          />
          <gl-link
            :href="webUrl"
            class="!gl-text-default gl-break-anywhere"
            data-testid="project-link"
          >
            {{ name }}
          </gl-link>
        </template>
      </gl-table-lite>
      <p class="gl-py-5 gl-text-center">
        {{
          s__(
            'ProductAnalytics|This table excludes projects that do not have product analytics onboarded.',
          )
        }}
      </p>
    </div>
  </div>
</template>
