<script>
import { GlFilteredSearchToken, GlDropdownDivider, GlDropdownSectionHeader } from '@gitlab/ui';
import { VULNERABILITY_STATE_OBJECTS } from 'ee/vulnerabilities/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__, n__ } from '~/locale';
import SearchSuggestion from '../components/search_suggestion.vue';
import QuerystringSync from '../../filters/querystring_sync.vue';
import { GROUPS } from '../../filters/status_filter.vue';
import { ALL_ID as ALL_STATUS_VALUE } from '../../filters/constants';
import eventHub from '../event_hub';

const { detected, confirmed } = VULNERABILITY_STATE_OBJECTS;

const ALL_DISMISSED_VALUE = GROUPS[1].options[0].value;
const DISMISSAL_REASON_VALUES = GROUPS[1].options.slice(1).map(({ value }) => value);
const OPTIONS = [...GROUPS[0].options, ...GROUPS[1].options];

export default {
  DEFAULT_VALUES: [detected.searchParamValue, confirmed.searchParamValue],
  VALID_VALUES: OPTIONS.map(({ value }) => value),
  GROUPS,
  queryStringDefaultValues: [ALL_STATUS_VALUE],
  components: {
    GlFilteredSearchToken,
    GlDropdownDivider,
    GlDropdownSectionHeader,
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
    const defaultSelected = this.value.data || this.$options.DEFAULT_VALUES;

    return {
      selectedStatuses: defaultSelected,
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
        data: this.active ? null : this.selectedStatuses,
      };
    },
    toggleText() {
      // "All dismissal reasons" option is selected
      if (this.selectedStatuses.length === 1 && this.selectedStatuses[0] === ALL_DISMISSED_VALUE) {
        return s__('SecurityReports|Dismissed (all reasons)');
      }

      // Dismissal reason(s) is selected
      if (this.selectedStatuses.every((value) => DISMISSAL_REASON_VALUES.includes(value))) {
        return n__(`Dismissed (%d reason)`, `Dismissed (%d reasons)`, this.selectedStatuses.length);
      }

      return getSelectedOptionsText({
        options: [...GROUPS[0].options, ...GROUPS[1].options],
        selected: this.selectedStatuses,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    resetSelected() {
      this.selectedStatuses = [];
      this.emitFiltersChanged();
    },

    emitFiltersChanged() {
      const dismissalReason = this.selectedStatuses.filter((value) =>
        DISMISSAL_REASON_VALUES.includes(value),
      );

      const state = this.selectedStatuses.filter(
        (value) => !DISMISSAL_REASON_VALUES.includes(value) && value !== ALL_STATUS_VALUE,
      );

      this.querySyncValues = this.selectedStatuses;
      eventHub.$emit('filters-changed', { state, dismissalReason });
    },

    updateSelectedFromQS(selected) {
      if (selected.includes(ALL_STATUS_VALUE)) {
        this.selectedStatuses = [ALL_STATUS_VALUE];
      } else if (selected.length > 0) {
        this.selectedStatuses = selected;
      } else {
        // This happens when we clear the token and re-select `Status`
        // to open the dropdown. At that stage we simply want to wait
        // for the user to select new statuses.
        if (!this.value.data) {
          return;
        }

        this.selectedStatuses = this.value.data || this.$options.DEFAULT_VALUES;
      }

      this.emitFiltersChanged();
    },

    toggleSelectedStatus(selectedValue) {
      const allStatusSelected = selectedValue === ALL_STATUS_VALUE;
      const allDismissedSelected = selectedValue === ALL_DISMISSED_VALUE;

      // Unselect
      if (this.selectedStatuses.includes(selectedValue)) {
        this.selectedStatuses = this.selectedStatuses.filter((s) => s !== selectedValue);

        if (this.selectedStatuses.length) {
          return;
        }
      }

      // If there is no option selected or the All Statuses option is selected, simply set
      // the array to ALL_STATUS_VALUE
      if (!this.selectedStatuses.length || allStatusSelected) {
        this.selectedStatuses = [ALL_STATUS_VALUE];
        return;
      }

      // Remove other dismissal values when All Dismissed option is selected
      if (allDismissedSelected) {
        this.selectedStatuses = this.selectedStatuses.filter(
          (s) => !DISMISSAL_REASON_VALUES.includes(s),
        );
      }
      // When a dismissal reason is selected, unselect All Dismissed option
      else if (DISMISSAL_REASON_VALUES.includes(selectedValue)) {
        this.selectedStatuses = this.selectedStatuses.filter((s) => s !== ALL_DISMISSED_VALUE);
      }

      // Otherwise select the item. Make sure to unselect ALL_STATUS_VALUE anyways because
      // selecting any value will deselect the `All statuses` option.
      this.selectedStatuses = this.selectedStatuses.filter((s) => s !== ALL_STATUS_VALUE);
      this.selectedStatuses.push(selectedValue);
    },
    isStatusSelected(name) {
      return this.selectedStatuses.some((s) => name === s);
    },
  },
  groups: {
    statusOptions: GROUPS[0].options,
    dismissalReasonOptions: GROUPS[1].options,
  },
  i18n: {
    statusLabel: s__('SecurityReports|Status'),
    dismissedAsLabel: GROUPS[1].text,
  },
};
</script>

<template>
  <querystring-sync
    ref="qs"
    querystring-key="state"
    :value="querySyncValues"
    :valid-values="$options.VALID_VALUES"
    :default-values="$options.queryStringDefaultValues"
    @input="updateSelectedFromQS"
  >
    <gl-filtered-search-token
      :config="config"
      v-bind="{ ...$props, ...$attrs }"
      :multi-select-values="selectedStatuses"
      :value="tokenValue"
      v-on="$listeners"
      @select="toggleSelectedStatus"
      @destroy="resetSelected"
      @complete="emitFiltersChanged"
    >
      <template #view>
        <span data-testid="status-token-placeholder">{{ toggleText }}</span>
      </template>
      <template #suggestions>
        <gl-dropdown-section-header>{{ $options.i18n.statusLabel }}</gl-dropdown-section-header>
        <gl-dropdown-divider />
        <search-suggestion
          v-for="status in $options.groups.statusOptions"
          :key="status.value"
          :text="status.text"
          :value="status.value"
          :selected="isStatusSelected(status.value)"
          :data-testid="`suggestion-${status.value}`"
        />
        <gl-dropdown-divider />
        <gl-dropdown-section-header>{{
          $options.i18n.dismissedAsLabel
        }}</gl-dropdown-section-header>
        <search-suggestion
          v-for="status in $options.groups.dismissalReasonOptions"
          :key="status.value"
          :text="status.text"
          :value="status.value"
          :selected="isStatusSelected(status.value)"
          :data-testid="`suggestion-${status.value}`"
        />
      </template>
    </gl-filtered-search-token>
  </querystring-sync>
</template>
