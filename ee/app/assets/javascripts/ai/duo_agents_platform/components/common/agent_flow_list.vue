<script>
import { GlEmptyState, GlKeysetPagination, GlLink, GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getTimeago } from '~/lib/utils/datetime/timeago_utility';
import { AGENTS_PLATFORM_SHOW_ROUTE } from '../../router/constants';
import { formatAgentFlowName, formatAgentStatus } from '../../utils';

export default {
  name: 'AgentFlowList',
  components: {
    GlEmptyState,
    GlKeysetPagination,
    GlLink,
    GlTableLite,
  },
  props: {
    emptyStateIllustrationPath: {
      required: true,
      type: String,
    },
    workflows: {
      required: true,
      type: Array,
    },
    workflowsPageInfo: {
      required: true,
      type: Object,
    },
  },
  computed: {
    hasWorkflows() {
      return this.workflows?.length > 0;
    },
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
    formatName({ workflowDefinition, id }) {
      return formatAgentFlowName(workflowDefinition, this.formatId(id));
    },
    formatStatus(status) {
      return formatAgentStatus(status);
    },
    formatUpdatedAt(timestamp) {
      try {
        return getTimeago().format(timestamp);
      } catch {
        return timestamp || '';
      }
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
  workflowFields: [
    { key: 'workflowDefinition', label: s__('DuoAgentsPlatform|Name') },
    { key: 'humanStatus', label: s__('DuoAgentsPlatform|Status') },
    { key: 'updatedAt', label: s__('DuoAgentsPlatform|Updated') },
    { key: 'id', label: s__('DuoAgentsPlatform|ID') },
  ],
};
</script>
<template>
  <div>
    <gl-empty-state
      v-if="!hasWorkflows"
      :title="s__('DuoAgentsPlatform|No agent sessions yet')"
      :description="s__('DuoAgentsPlatform|New agent sessions will appear here.')"
      :svg-path="emptyStateIllustrationPath"
    />
    <template v-else>
      <gl-table-lite :fields="$options.workflowFields" :items="workflows">
        <template #cell(workflowDefinition)="{ item }">
          <gl-link :to="{ name: $options.showRoute, params: { id: formatId(item.id) } }">
            {{ formatName(item) }}
          </gl-link>
        </template>
        <template #cell(humanStatus)="{ item }">{{ formatStatus(item.humanStatus) }}</template>
        <template #cell(updatedAt)="{ item }">{{ formatUpdatedAt(item.updatedAt) }}</template>
        <template #cell(id)="{ item }">
          {{ formatId(item.id) }}
        </template>
      </gl-table-lite>
      <gl-keyset-pagination
        v-bind="workflowsPageInfo"
        class="gl-mt-5 gl-flex gl-justify-center"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </template>
  </div>
</template>
