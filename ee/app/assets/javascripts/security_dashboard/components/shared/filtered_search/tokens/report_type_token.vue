<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { REPORT_TYPES_WITH_MANUALLY_ADDED } from 'ee/security_dashboard/constants';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import SearchSuggestion from '../components/search_suggestion.vue';
import QuerystringSync from '../../filters/querystring_sync.vue';
import { ALL_ID as ALL_REPORT_TYPES_ID } from '../../filters/constants';
import eventHub from '../event_hub';

export const DEFAULT_VENDORS = ['', 'GitLab'];

export default {
  components: {
    QuerystringSync,
    GlFilteredSearchToken,
    SearchSuggestion,
  },
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
    const defaultSelected = this.value.data || [ALL_REPORT_TYPES_ID];

    return {
      selectedReportTypes: defaultSelected,
      querySyncValues: defaultSelected,
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedReportTypes,
      };
    },
    items() {
      const allOption = { value: ALL_REPORT_TYPES_ID, text: this.$options.i18n.allItemsText };
      const reportTypes = REPORT_TYPES_WITH_MANUALLY_ADDED;

      const options = Object.entries(reportTypes).map(([id, text]) => ({
        value: id.toUpperCase(),
        text,
      }));

      return [allOption, ...options];
    },
    validValues() {
      return this.items.map((i) => i.value);
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.items,
        selected: this.selectedReportTypes,
        placeholder: this.$options.i18n.allItemsText,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    resetSelected() {
      this.selectedReportTypes = [ALL_REPORT_TYPES_ID];
      this.emitFiltersChanged();
    },
    emitFiltersChanged() {
      this.querySyncValues = this.selectedReportTypes;

      eventHub.$emit('filters-changed', {
        reportType: this.selectedReportTypes.filter((i) => i !== ALL_REPORT_TYPES_ID),
      });
    },
    updateSelected(selectedValue) {
      if (selectedValue === ALL_REPORT_TYPES_ID) {
        this.selectedReportTypes = [ALL_REPORT_TYPES_ID];
        return;
      }

      // Make sure to remove the All Report Types selection
      this.selectedReportTypes = this.selectedReportTypes.filter((i) => i !== ALL_REPORT_TYPES_ID);

      if (this.selectedReportTypes.includes(selectedValue)) {
        this.selectedReportTypes = this.selectedReportTypes.filter((i) => i !== selectedValue);
      } else {
        this.selectedReportTypes.push(selectedValue);
      }

      if (this.selectedReportTypes.length === 0) {
        this.selectedReportTypes = [ALL_REPORT_TYPES_ID];
      }
    },
    updateSelectedFromQS(selected) {
      if (selected.includes(ALL_REPORT_TYPES_ID)) {
        this.selectedReportTypes = [ALL_REPORT_TYPES_ID];
      } else if (selected.length > 0) {
        this.selectedReportTypes = selected;
      } else {
        // This happens when we clear the token and re-select `Status`
        // to open the dropdown. At that stage we simply want to wait
        // for the user to select new statuses.
        if (!this.value.data) {
          return;
        }

        this.selectedReportTypes = this.value.data;
      }

      this.emitFiltersChanged();
    },
    isReportTypeSelected(name) {
      return Boolean(this.selectedReportTypes.find((s) => name === s));
    },
  },
  i18n: {
    label: s__('SecurityReports|Report type'),
    allItemsText: s__('SecurityReports|All report types'),
  },
  ALL_REPORT_TYPES_ID,
};
</script>

<template>
  <querystring-sync
    querystring-key="reportType"
    :value="querySyncValues"
    :valid-values="validValues"
    data-testid="report-type-token"
    @input="updateSelectedFromQS"
  >
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selectedReportTypes"
      :value="tokenValue"
      v-on="$listeners"
      @select="updateSelected"
      @destroy="resetSelected"
      @complete="emitFiltersChanged"
    >
      <template #view>
        <span data-testid="report-type-token-value">
          {{ toggleText }}
        </span>
      </template>
      <template #suggestions>
        <search-suggestion
          v-for="reportType in items"
          :key="reportType.value"
          :value="reportType.value"
          :text="reportType.text"
          :selected="isReportTypeSelected(reportType.value)"
          :data-testid="`suggestion-${reportType.value}`"
        />
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
