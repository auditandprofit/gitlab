<script>
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { __ } from '~/locale';
import NameCell from './name_cell.vue';
import VulnerabilityCell from './vulnerability_cell.vue';
import ToolCoverageCell from './tool_coverage_cell.vue';
import ActionCell from './action_cell.vue';

const SKELETON_ROW_COUNT = 3;

export default {
  components: {
    GlTableLite,
    GlSkeletonLoader,
    NameCell,
    VulnerabilityCell,
    ToolCoverageCell,
    ActionCell,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasSearch: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    displayItems() {
      return this.isLoading && this.items.length === 0
        ? Array(SKELETON_ROW_COUNT).fill({})
        : this.items;
    },
  },
  fields: [
    { key: 'name', label: __('Name'), thClass: 'gl-max-w-0' },
    { key: 'vulnerabilities', label: __('Vulnerabilities'), thClass: 'gl-w-1/5' },
    { key: 'toolCoverage', label: __('Tool Coverage'), thClass: 'gl-w-1/3' },
    { key: 'actions', label: '', thClass: 'gl-w-2/20' },
  ],
};
</script>

<template>
  <gl-table-lite :items="displayItems" :fields="$options.fields" hover table-class="gl-table-fixed">
    <template #cell(name)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :width="200" :height="20" preserve-aspect-ratio="none">
        <rect x="0" y="5" width="15" height="15" rx="3" />
        <rect x="24" y="5" width="50" height="5" rx="2" />
        <rect x="24" y="15" width="100" height="5" rx="2" />
      </gl-skeleton-loader>
      <name-cell v-else :item="item" :show-search-param="hasSearch" />
    </template>

    <template #cell(vulnerabilities)="{ item, index }">
      <gl-skeleton-loader v-if="isLoading" :width="250" :height="20">
        <rect x="0" y="6" width="230" height="13" rx="6" />
      </gl-skeleton-loader>
      <vulnerability-cell v-else :item="item" :index="index" />
    </template>

    <template #cell(toolCoverage)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :width="300" :height="30" preserve-aspect-ratio="none">
        <rect x="0" y="5" width="32" height="20" rx="10" />
        <rect x="38" y="5" width="32" height="20" rx="10" />
        <rect x="76" y="5" width="32" height="20" rx="10" />
        <rect x="114" y="5" width="32" height="20" rx="10" />
        <rect x="152" y="5" width="32" height="20" rx="10" />
        <rect x="190" y="5" width="32" height="20" rx="10" />
      </gl-skeleton-loader>
      <tool-coverage-cell v-else :item="item" />
    </template>

    <template #cell(actions)="{ item }">
      <gl-skeleton-loader v-if="isLoading" :width="32" :height="18">
        <rect x="0" y="3" width="12" height="12" rx="2" />
      </gl-skeleton-loader>
      <action-cell v-else :item="item" />
    </template>
  </gl-table-lite>
</template>
