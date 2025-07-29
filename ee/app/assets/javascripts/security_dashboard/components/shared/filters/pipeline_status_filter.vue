<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { VULNERABILITY_STATE_OBJECTS } from 'ee/vulnerabilities/constants';
import QuerystringSync from './querystring_sync.vue';
import { ALL_ID as ALL_STATUS_VALUE } from './constants';

const { detected, confirmed, dismissed, resolved } = VULNERABILITY_STATE_OBJECTS;
export const OPTIONS = [
  { value: ALL_STATUS_VALUE, text: s__('SecurityReports|All statuses') },
  { value: detected.searchParamValue, text: detected.buttonText },
  { value: confirmed.searchParamValue, text: confirmed.buttonText },
  { value: dismissed.searchParamValue, text: dismissed.buttonText },
  { value: resolved.searchParamValue, text: resolved.buttonText },
];

const VALID_VALUES = OPTIONS.map(({ value }) => value);
const DEFAULT_VALUES = [detected.searchParamValue];

export default {
  components: {
    GlCollapsibleListbox,
    QuerystringSync,
  },
  data: () => ({
    selected: DEFAULT_VALUES,
  }),
  computed: {
    toggleText() {
      return getSelectedOptionsText({ options: OPTIONS, selected: this.selected });
    },
  },
  watch: {
    selected: {
      immediate: true,
      handler() {
        this.$emit('filter-changed', {
          state: this.selected.filter((value) => value !== ALL_STATUS_VALUE),
        });
      },
    },
  },

  methods: {
    updateSelected(selected) {
      if (selected.length <= 0 || selected.at(-1) === ALL_STATUS_VALUE) {
        this.selected = [ALL_STATUS_VALUE];
      } else {
        this.selected = selected.filter((value) => value !== ALL_STATUS_VALUE);
      }
    },
    updateSelectedFromQS(selected) {
      if (selected.includes(ALL_STATUS_VALUE)) {
        this.selected = [ALL_STATUS_VALUE];
      } else if (selected.length > 0) {
        this.selected = selected;
      } else {
        this.selected = DEFAULT_VALUES;
      }
    },
  },
  i18n: {
    label: s__('SecurityReports|Status'),
  },
  OPTIONS,
  VALID_VALUES,
};
</script>

<template>
  <div>
    <querystring-sync
      querystring-key="state"
      :value="selected"
      :valid-values="$options.VALID_VALUES"
      @input="updateSelectedFromQS"
    />
    <label class="gl-mb-2">{{ $options.i18n.label }}</label>
    <gl-collapsible-listbox
      :header-text="$options.i18n.label"
      block
      multiple
      :items="$options.OPTIONS"
      :selected="selected"
      :toggle-text="toggleText"
      data-testid="filter-status-dropdown"
      @select="updateSelected"
    />
  </div>
</template>
