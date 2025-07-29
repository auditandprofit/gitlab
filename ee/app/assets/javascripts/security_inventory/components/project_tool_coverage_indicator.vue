<script>
import { GlBadge, GlPopover } from '@gitlab/ui';
import { itemValidator } from 'ee/security_inventory/utils';
import {
  SCANNER_POPOVER_GROUPS,
  SCANNER_TYPES,
  SECRET_PUSH_PROTECTION_KEY,
  CONTAINER_SCANNING_FOR_REGISTRY_KEY,
} from '../constants';
import ProjectToolCoverageDetails from './project_tool_coverage_details.vue';

export default {
  components: { GlBadge, GlPopover, ProjectToolCoverageDetails },
  props: {
    item: {
      type: Object,
      required: true,
      validator: (value) => itemValidator(value),
    },
  },
  methods: {
    getRelevantScannerData(scannerTypes) {
      return scannerTypes.map((type) => {
        if (type === SECRET_PUSH_PROTECTION_KEY) {
          return {
            analyzerType: type,
            status: this.item.secretPushProtectionEnabled ? 'SUCCESS' : 'DEFAULT',
          };
        }
        if (type === CONTAINER_SCANNING_FOR_REGISTRY_KEY) {
          return {
            analyzerType: type,
            status: this.item.containerScanningForRegistryEnabled ? 'SUCCESS' : 'DEFAULT',
          };
        }

        const existingScanner = this.item.analyzerStatuses.find(
          (scanner) => scanner.analyzerType === type,
        );

        const defaultType = { analyzerType: type };
        return existingScanner || defaultType;
      });
    },
    scannerStyling(scannerTypes) {
      const relevantScanner = this.getRelevantScannerData(scannerTypes);
      if (relevantScanner.some((status) => status.status === 'FAILED')) {
        return { variant: 'danger', class: 'gl-border-red-600' };
      }
      if (relevantScanner.some((status) => status.status === 'SUCCESS')) {
        return { variant: 'success', class: 'gl-border-transparent' };
      }
      return { class: '!gl-bg-default !gl-text-neutral-600 gl-border-gray-200 gl-border-dashed' };
    },
    getToolCoverageTitle(key) {
      return SCANNER_TYPES[key].name;
    },
    getLabel(key) {
      return SCANNER_TYPES[key].textLabel;
    },
  },
  SCANNER_POPOVER_GROUPS,
};
</script>

<template>
  <div class="gl-flex gl-flex-row gl-flex-wrap gl-gap-2">
    <div v-for="(value, key) in $options.SCANNER_POPOVER_GROUPS" :key="key">
      <gl-badge
        :id="`tool-coverage-${key}-${item.path}`"
        v-bind="scannerStyling(value)"
        class="gl-border gl-w-8 gl-text-xs gl-font-bold"
        :data-testid="`badge-${key}-${item.path}`"
      >
        {{ getLabel(key) }}
      </gl-badge>
      <gl-popover
        :css-classes="['gl-max-w-full']"
        :title="getToolCoverageTitle(key)"
        :target="`tool-coverage-${key}-${item.path}`"
        :data-testid="`popover-${key}-${item.path}`"
        show-close-button
      >
        <project-tool-coverage-details
          :security-scanner="getRelevantScannerData(value)"
          :web-url="item.webUrl"
        />
      </gl-popover>
    </div>
  </div>
</template>
