<script>
import { GlSkeletonLoader, GlTooltipDirective } from '@gitlab/ui';
import { GlColumnChart } from '@gitlab/ui/dist/charts';
import { s__, sprintf } from '~/locale';
import {
  findCurrentMonthUsage,
  findPreviousMonthUsage,
  projectsUsageDataValidator,
} from '../utils';

// Trying to show more than this many projects on a single chart starts to
// get illegible, so we only render this many projects if there's many
const MAX_PROJECTS_TO_CHART = 50;

export default {
  name: 'ProductAnalyticsProjectsUsageChart',
  components: {
    GlColumnChart,
    GlSkeletonLoader,
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
    showChart() {
      return this.projectsUsageData && this.projectsUsageData?.length !== 0;
    },
    xAxisTitle() {
      if (this.projectsUsageData?.length <= MAX_PROJECTS_TO_CHART) {
        return s__('ProductAnalytics|Projects');
      }

      return sprintf(s__(`ProductAnalytics|Projects (%{maxProjects} of %{totalProjects} shown)`), {
        maxProjects: MAX_PROJECTS_TO_CHART,
        totalProjects: this.projectsUsageData.length,
      });
    },
    chartSeries() {
      return [
        {
          name: s__('ProductAnalytics|Previous month'),
          stack: 'previous',
          data: this.projectsUsageData
            ?.map((project) => {
              return [project.name, findPreviousMonthUsage(project).count];
            })
            .slice(0, MAX_PROJECTS_TO_CHART),
        },
        {
          name: s__('ProductAnalytics|Current month to date'),
          stack: 'current',
          data: this.projectsUsageData
            ?.map((project) => {
              return [project.name, findCurrentMonthUsage(project).count];
            })
            .slice(0, MAX_PROJECTS_TO_CHART),
        },
      ];
    },
  },
};
</script>
<template>
  <div class="gl-mb-7">
    <gl-skeleton-loader v-if="isLoading" :lines="3" />
    <gl-column-chart
      v-else-if="showChart"
      :bars="chartSeries"
      x-axis-type="category"
      :x-axis-title="xAxisTitle"
      :y-axis-title="s__('ProductAnalytics|Events')"
    />
  </div>
</template>
