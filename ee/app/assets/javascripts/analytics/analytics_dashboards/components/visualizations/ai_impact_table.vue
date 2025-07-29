<script>
import { GlLoadingIcon } from '@gitlab/ui';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';

export default {
  name: 'AiImpactTable',
  components: {
    GlLoadingIcon,
    GroupOrProjectProvider,
    MetricTable,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
  computed: {
    excludeMetrics() {
      const { filters: { excludeMetrics = [] } = {} } = this.data;
      return excludeMetrics;
    },
  },
};
</script>
<template>
  <group-or-project-provider
    #default="{ isProject, isNamespaceLoading }"
    :full-path="data.namespace"
  >
    <div v-if="isNamespaceLoading" class="gl-flex gl-h-full gl-items-center gl-justify-center">
      <gl-loading-icon size="lg" />
    </div>
    <metric-table
      v-else
      :namespace="data.namespace"
      :is-project="isProject"
      :exclude-metrics="excludeMetrics"
      @set-alerts="$emit('set-alerts', $event)"
    />
  </group-or-project-provider>
</template>
