<script>
import { GlBadge, GlCollapsibleListbox, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { without } from 'lodash';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import QuerystringSync from './querystring_sync.vue';
import { ALL_ID } from './constants';

export const ITEMS = {
  STILL_DETECTED: {
    value: 'STILL_DETECTED',
    text: s__('SecurityReports|Still detected'),
  },
  NO_LONGER_DETECTED: {
    value: 'NO_LONGER_DETECTED',
    text: s__('SecurityReports|No longer detected'),
  },
  HAS_ISSUE: {
    value: 'HAS_ISSUE',
    text: s__('SecurityReports|Has issue'),
  },
  DOES_NOT_HAVE_ISSUE: {
    value: 'DOES_NOT_HAVE_ISSUE',
    text: s__('SecurityReports|Does not have issue'),
  },
  HAS_MERGE_REQUEST: {
    value: 'HAS_MERGE_REQUEST',
    text: s__('SecurityReports|Has merge request'),
  },
  DOES_NOT_HAVE_MERGE_REQUEST: {
    value: 'DOES_NOT_HAVE_MERGE_REQUEST',
    text: s__('SecurityReports|Does not have merge request'),
  },
  HAS_SOLUTION: {
    value: 'HAS_SOLUTION',
    text: s__('SecurityReports|Has a solution'),
  },
  DOES_NOT_HAVE_SOLUTION: {
    value: 'DOES_NOT_HAVE_SOLUTION',
    text: s__('SecurityReports|Does not have a solution'),
  },
};

export const GROUPS = [
  {
    text: '',
    options: [
      {
        value: ALL_ID,
        text: s__('SecurityReports|All activity'),
      },
    ],
    textSrOnly: true,
  },
  {
    text: s__('SecurityReports|Detection'),
    options: [ITEMS.STILL_DETECTED, ITEMS.NO_LONGER_DETECTED],
    icon: 'check-circle-dashed',
    variant: 'info',
  },
  {
    text: s__('SecurityReports|Issue'),
    options: [ITEMS.HAS_ISSUE, ITEMS.DOES_NOT_HAVE_ISSUE],
    icon: 'issues',
  },
  {
    text: s__('SecurityReports|Merge Request'),
    options: [ITEMS.HAS_MERGE_REQUEST, ITEMS.DOES_NOT_HAVE_MERGE_REQUEST],
    icon: 'merge-request',
  },
  {
    text: s__('SecurityReports|Solution available'),
    options: [ITEMS.HAS_SOLUTION, ITEMS.DOES_NOT_HAVE_SOLUTION],
    icon: 'bulb',
  },
];

const DEFAULT_VALUES = [ITEMS.STILL_DETECTED.value];

export default {
  components: {
    GlBadge,
    QuerystringSync,
    GlCollapsibleListbox,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  data: () => ({
    selected: DEFAULT_VALUES,
  }),
  computed: {
    toggleText() {
      return getSelectedOptionsText({
        options: Object.values(ITEMS),
        selected: this.selected,
        placeholder: this.$options.i18n.allItemsText,
      });
    },
    selectedItems() {
      return this.selected.length ? this.selected : [ALL_ID];
    },
    items() {
      const groups = [...GROUPS];
      return groups;
    },
  },
  watch: {
    selected: {
      immediate: true,
      handler() {
        const hasResolution = this.setSelectedValue('NO_LONGER_DETECTED', 'STILL_DETECTED');
        const hasIssues = this.setSelectedValue('HAS_ISSUE', 'DOES_NOT_HAVE_ISSUE');
        const hasMergeRequest = this.setSelectedValue(
          'HAS_MERGE_REQUEST',
          'DOES_NOT_HAVE_MERGE_REQUEST',
        );
        const hasRemediations = this.setSelectedValue('HAS_SOLUTION', 'DOES_NOT_HAVE_SOLUTION');

        this.$emit('filter-changed', {
          hasResolution,
          hasIssues,
          hasMergeRequest,
          hasRemediations,
        });
      },
    },
  },
  methods: {
    getGroupFromItem(value) {
      return this.items.find((group) =>
        group.options.map((option) => option.value).includes(value),
      );
    },
    updateSelected(selected) {
      const selectedValue = selected?.at(-1);

      const noneSelected = selected.length <= 0;
      const allIdSelected = selectedValue === ALL_ID;

      if (noneSelected || allIdSelected) {
        this.selected = [ALL_ID];
        return;
      }

      const selectedWithoutAll = without(selected, ALL_ID);
      // Test whether a new item is selected by checking if `selected`
      // (without ALL_ID option) length is larger than `this.selected` length.
      const isSelecting = selectedWithoutAll.length > this.selected.length;
      // If a new item is selected, clear other selected items from the same group and select the new item.
      if (isSelecting) {
        const group = this.getGroupFromItem(selectedValue);
        const groupItemIds = group.options.map((option) => option.value);
        this.selected = without(this.selected, ...groupItemIds).concat(selectedValue);
      }
      // Otherwise, if item is being unselected, just take `selectedWithoutAll` as `this.selected`.
      else {
        this.selected = selectedWithoutAll;
      }
    },
    updateSelectedFromQS(selected) {
      if (selected.includes(ALL_ID)) {
        this.selected = [ALL_ID];
      } else if (selected.length > 0) {
        this.selected = selected;
      } else {
        this.selected = DEFAULT_VALUES;
      }
    },
    setSelectedValue(keyWhenTrue, keyWhenFalse) {
      // The variables can be true, false, or unset, so we need to use if/else-if here instead
      // of if/else.
      if (this.selected.includes(ITEMS[keyWhenTrue].value)) return true;
      if (this.selected.includes(ITEMS[keyWhenFalse].value)) return false;
      return undefined;
    },
  },
  i18n: {
    label: s__('SecurityReports|Activity'),
    allItemsText: s__('SecurityReports|All activity'),
    activityFilterTooltip: s__(
      'SecurityReports|The Activity filter now defaults to showing only vulnerabilities that are "still detected". To see vulnerabilities regardless of their detection status, remove this filter.',
    ),
  },
};
</script>

<template>
  <div>
    <querystring-sync v-model="selected" querystring-key="activity" @input="updateSelectedFromQS" />
    <label class="gl-mb-2">{{ $options.i18n.label }}</label>
    <gl-icon
      v-gl-tooltip="$options.i18n.activityFilterTooltip"
      name="status-active"
      :size="12"
      class="gl-text-blue-500"
    />
    <gl-collapsible-listbox
      :items="items"
      :selected="selectedItems"
      :header-text="$options.i18n.label"
      :toggle-text="toggleText"
      multiple
      block
      data-testid="filter-activity-dropdown"
      @select="updateSelected"
    >
      <template #group-label="{ group }">
        <div
          v-if="group.icon"
          class="gl-flex gl-items-center gl-justify-center gl-pr-4"
          :data-testid="`header-${group.text}`"
        >
          <div class="gl-grow">{{ group.text }}</div>
          <gl-badge :icon="group.icon" :variant="group.variant" />
        </div>
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
