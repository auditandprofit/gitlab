<script>
import { GlFilteredSearchToken, GlDropdownDivider, GlDropdownSectionHeader } from '@gitlab/ui';
import { groupBy } from 'lodash';
import {
  REPORT_TYPES_DEFAULT,
  REPORT_TYPES_WITH_MANUALLY_ADDED,
} from 'ee/security_dashboard/constants';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import SearchSuggestion from '../components/search_suggestion.vue';
import QuerystringSync from '../../filters/querystring_sync.vue';
import { ALL_ID as ALL_TOOLS_ID } from '../../filters/constants';
import eventHub from '../event_hub';

export const DEFAULT_VENDORS = ['', 'GitLab'];

export default {
  components: {
    QuerystringSync,
    GlFilteredSearchToken,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    SearchSuggestion,
  },
  inject: ['scanners', 'toolFilterType'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    const defaultSelected = this.value.data || [ALL_TOOLS_ID];

    return {
      selectedTools: defaultSelected,
      querySyncValues: defaultSelected,
    };
  },
  computed: {
    isSimpleTool() {
      return this.toolFilterType === 'reportType';
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedTools,
      };
    },
    items() {
      if (this.isSimpleTool) {
        return this.itemsFromConfig;
      }

      return this.itemsFromScanners;
    },
    itemsFromConfig() {
      const allOption = { value: ALL_TOOLS_ID, text: this.$options.i18n.allItemsText };
      const reportTypes = REPORT_TYPES_WITH_MANUALLY_ADDED;

      const options = Object.entries(reportTypes).map(([id, text]) => ({
        value: id.toUpperCase(),
        text,
      }));

      return [allOption, ...options];
    },
    itemsFromScanners() {
      const groupedByReport = groupBy(this.scanners, 'report_type');
      const items = [
        {
          text: this.$options.i18n.label,
          options: [
            {
              value: ALL_TOOLS_ID,
              text: this.$options.i18n.allItemsText,
            },
            {
              value: 'gitlab-manual-vulnerability-report',
              text: REPORT_TYPES_WITH_MANUALLY_ADDED.generic,
            },
          ],
        },
      ];

      // Create the dropdown options for the report types that have scanners
      Object.entries(REPORT_TYPES_DEFAULT).forEach(([reportType, text]) => {
        const scanners = groupedByReport[reportType.toUpperCase()];

        // Don't include the report type if there are no scanners for it
        if (!scanners) {
          return;
        }

        items.push({
          text,
          options: scanners.map((scanner) => ({
            value: scanner.external_id,
            text: DEFAULT_VENDORS.includes(scanner.vendor)
              ? scanner.name
              : `${scanner.name} (${scanner.vendor})`,
          })),
        });
      });

      return items;
    },
    flatItems() {
      return this.items.flatMap((i) => i.options);
    },
    validValues() {
      if (this.isSimpleTool) {
        return this.items.map((i) => i.value);
      }

      return this.flatItems.map((i) => i.value);
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.isSimpleTool ? this.items : this.flatItems,
        selected: this.selectedTools,
        placeholder: this.$options.i18n.allItemsText,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    resetSelected() {
      this.selectedTools = [ALL_TOOLS_ID];
      this.emitFiltersChanged();
    },
    emitFiltersChanged() {
      this.querySyncValues = this.selectedTools;

      eventHub.$emit('filters-changed', {
        [this.toolFilterType]: this.selectedTools.filter((i) => i !== ALL_TOOLS_ID),
      });
    },
    updateSelected(selectedValue) {
      if (selectedValue === ALL_TOOLS_ID) {
        this.selectedTools = [ALL_TOOLS_ID];
        return;
      }

      // Make sure to remove the All Tools selection
      this.selectedTools = this.selectedTools.filter((i) => i !== ALL_TOOLS_ID);

      if (this.selectedTools.includes(selectedValue)) {
        this.selectedTools = this.selectedTools.filter((i) => i !== selectedValue);
      } else {
        this.selectedTools.push(selectedValue);
      }

      if (this.selectedTools.length === 0) {
        this.selectedTools = [ALL_TOOLS_ID];
      }
    },
    updateSelectedFromQS(selected) {
      if (selected.includes(ALL_TOOLS_ID)) {
        this.selectedTools = [ALL_TOOLS_ID];
      } else if (selected.length > 0) {
        this.selectedTools = selected;
      } else {
        // This happens when we clear the token and re-select `Status`
        // to open the dropdown. At that stage we simply want to wait
        // for the user to select new statuses.
        if (!this.value.data) {
          return;
        }

        this.selectedTools = this.value.data;
      }

      this.emitFiltersChanged();
    },
    isToolSelected(name) {
      return Boolean(this.selectedTools.find((s) => name === s));
    },
  },
  i18n: {
    label: s__('SecurityReports|Tool'),
    allItemsText: s__('SecurityReports|All tools'),
  },
  ALL_TOOLS_ID,
};
</script>

<template>
  <querystring-sync
    :querystring-key="toolFilterType"
    :value="querySyncValues"
    :valid-values="validValues"
    data-testid="tool-token"
    @input="updateSelectedFromQS"
  >
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selectedTools"
      :value="tokenValue"
      v-on="$listeners"
      @select="updateSelected"
      @destroy="resetSelected"
      @complete="emitFiltersChanged"
    >
      <template #view>
        <span data-testid="tool-token-value">
          {{ toggleText }}
        </span>
      </template>
      <template #suggestions>
        <template v-if="isSimpleTool">
          <search-suggestion
            v-for="tool in items"
            :key="tool.value"
            :text="tool.text"
            :value="tool.value"
            :selected="isToolSelected(tool.value)"
            :data-testid="`suggestion-${tool.value}`"
          />
        </template>
        <template v-for="(group, index) in items" v-else>
          <gl-dropdown-section-header v-if="group.text" :key="group.value">
            {{ group.text }}
          </gl-dropdown-section-header>
          <gl-dropdown-divider v-if="index === 0" :key="group.value" />
          <search-suggestion
            v-for="tool in group.options"
            :key="tool.value"
            :text="tool.text"
            :value="tool.value"
            :selected="isToolSelected(tool.value)"
            :data-testid="`suggestion-${tool.value}`"
          />
        </template>
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
