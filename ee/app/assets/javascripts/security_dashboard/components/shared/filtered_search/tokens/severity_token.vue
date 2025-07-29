<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import QuerystringSync from '../../filters/querystring_sync.vue';
import { ALL_ID as ALL_SEVERITIES_VALUE } from '../../filters/constants';
import SearchSuggestion from '../components/search_suggestion.vue';
import eventHub from '../event_hub';

const VALID_IDS = Object.entries(SEVERITY_LEVELS).map(([id]) => id.toUpperCase());

export default {
  VALID_IDS,

  components: {
    GlFilteredSearchToken,
    QuerystringSync,
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
    return {
      selectedSeverities: this.value.data || [ALL_SEVERITIES_VALUE],
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedSeverities,
      };
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.$options.items,
        selected: this.selectedSeverities,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    emitFiltersChanged() {
      eventHub.$emit('filters-changed', {
        severity: this.selectedSeverities.filter((value) => value !== ALL_SEVERITIES_VALUE),
      });
    },
    resetSelected() {
      this.selectedSeverities = [ALL_SEVERITIES_VALUE];
      this.emitFiltersChanged();
    },
    updateSelectedFromQS(values) {
      // This happens when we clear the token and re-select `Severity`
      // to open the dropdown. At that stage we simply want to wait
      // for the user to select new severities.
      if (!values.length) {
        return;
      }

      this.selectedSeverities = values;
      this.emitFiltersChanged();
    },
    toggleSelected(selectedValue) {
      const allSeveritiesSelected = selectedValue === ALL_SEVERITIES_VALUE;

      if (this.selectedSeverities.includes(selectedValue)) {
        this.selectedSeverities = this.selectedSeverities.filter((s) => s !== selectedValue);
      } else {
        this.selectedSeverities = this.selectedSeverities.filter((s) => s !== ALL_SEVERITIES_VALUE);
        this.selectedSeverities.push(selectedValue);
      }

      if (!this.selectedSeverities.length || allSeveritiesSelected) {
        this.selectedSeverities = [ALL_SEVERITIES_VALUE];
      }
    },
    isSeveritySelected(name) {
      return Boolean(this.selectedSeverities.find((s) => name === s));
    },
  },
  i18n: {
    label: s__('SecurityReports|Severity'),
  },
  items: [
    {
      value: ALL_SEVERITIES_VALUE,
      text: s__('SecurityReports|All severities'),
    },
    ...Object.entries(SEVERITY_LEVELS).map(([id, text]) => ({
      value: id.toUpperCase(),
      text,
    })),
  ],
};
</script>

<template>
  <querystring-sync
    querystring-key="severity"
    :value="selectedSeverities"
    :valid-values="$options.VALID_IDS"
    @input="updateSelectedFromQS"
  >
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selectedSeverities"
      :value="tokenValue"
      v-on="$listeners"
      @select="toggleSelected"
      @destroy="resetSelected"
      @complete="emitFiltersChanged"
    >
      <template #view>
        <span data-testid="severity-token-placeholder">{{ toggleText }}</span>
      </template>
      <template #suggestions>
        <search-suggestion
          v-for="severity in $options.items"
          :key="severity.value"
          :value="severity.value"
          :text="severity.text"
          :selected="isSeveritySelected(severity.value)"
          :data-testid="`suggestion-${severity.value}`"
        />
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
