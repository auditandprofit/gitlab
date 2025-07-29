<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { groupBy } from 'lodash';
import { s__ } from '~/locale';
import {
  REPORT_TYPES_DEFAULT,
  REPORT_TYPES_WITH_MANUALLY_ADDED,
} from 'ee/security_dashboard/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { REPORT_TYPE_PRESETS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';
import QuerystringSync from './querystring_sync.vue';
import { ALL_ID } from './constants';

// Due to legacy reasons, some scanner vendors are blank. We'll treat these as GitLab scanners.
export const DEFAULT_VENDORS = ['', 'GitLab'];

export default {
  components: {
    QuerystringSync,
    GlCollapsibleListbox,
  },
  inject: ['scanners'],
  data() {
    return {
      selected: [],
    };
  },
  computed: {
    selectedIds() {
      // This prevents the querystring-sync component from redirecting the page to /?scanner_id=ALL.
      return this.selected.length ? this.selected : [ALL_ID];
    },

    toggleText() {
      return getSelectedOptionsText({
        options: this.items.flatMap(({ options }) => options),
        selected: this.selectedIds,
        placeholder: this.$options.i18n.allItemsText,
      });
    },

    items() {
      const allOption = { value: ALL_ID, text: this.$options.i18n.allItemsText };
      const manuallyAddedOption = {
        value: 'gitlab-manual-vulnerability-report',
        text: REPORT_TYPES_WITH_MANUALLY_ADDED.generic,
      };
      const groupedByReport = groupBy(this.scanners, 'report_type');
      const optionsWithScanners = [];

      // Create the dropdown options for the report types that have scanners
      Object.entries(REPORT_TYPES_DEFAULT).forEach(([reportType, text]) => {
        const scanners = groupedByReport[reportType.toUpperCase()];

        // Don't include the report type if there are no scanners for it
        if (!scanners) {
          return;
        }

        const options = scanners.map((scanner) => ({
          value: scanner.external_id,
          text: DEFAULT_VENDORS.includes(scanner.vendor)
            ? scanner.name
            : `${scanner.name} (${scanner.vendor})`,
        }));

        optionsWithScanners.push({ text, options });
      });

      return [
        {
          text: '',
          textSrOnly: true,
          options: [allOption, manuallyAddedOption],
        },
        ...optionsWithScanners,
      ];
    },
  },
  watch: {
    selected() {
      if (!this.selected.length) {
        // This will send the filter presets (no "Cluster Image Scanning") for the development tab
        this.$emit('filter-changed', {
          reportType: REPORT_TYPE_PRESETS.DEVELOPMENT,
          scanner: undefined,
        });
        return;
      }

      this.$emit('filter-changed', { scanner: this.selected, reportType: undefined });
    },
  },
  methods: {
    updateSelected(selected) {
      if (selected.at(-1) === ALL_ID || !selected.length) {
        this.selected = [];
      } else if (selected.length > 0) {
        this.selected = selected.filter((s) => s !== ALL_ID);
      }
    },
  },
  i18n: {
    label: s__('SecurityReports|Tool'),
    allItemsText: s__('ciReport|All tools'),
  },
};
</script>

<template>
  <div>
    <querystring-sync v-model="selected" querystring-key="scanner" />
    <label class="gl-mb-2">{{ $options.i18n.label }}</label>
    <gl-collapsible-listbox
      :items="items"
      :header-text="$options.i18n.label"
      :toggle-text="toggleText"
      :selected="selectedIds"
      multiple
      block
      data-testid="filter-tool-dropdown"
      @select="updateSelected"
    />
  </div>
</template>
