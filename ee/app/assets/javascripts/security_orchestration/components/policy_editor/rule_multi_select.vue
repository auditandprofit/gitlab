<script>
import { GlCollapsibleListbox, GlTruncate } from '@gitlab/ui';

import { s__, sprintf } from '~/locale';
import { renderMultiSelectText } from './utils';

export default {
  components: {
    GlCollapsibleListbox,
    GlTruncate,
  },
  props: {
    itemTypeName: {
      type: String,
      required: true,
    },
    items: {
      type: Object,
      required: true,
    },
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
    includeSelectAll: {
      type: Boolean,
      required: false,
      default: () => true,
    },
  },
  data() {
    return {
      selected: [...this.value],
    };
  },
  computed: {
    listBoxItems() {
      return Object.entries(this.items).map(([value, text]) => ({ value, text }));
    },
    listBoxHeader() {
      return sprintf(this.$options.i18n.selectPolicyListboxHeader, {
        itemTypeName: this.itemTypeName,
      });
    },
    selectAllLabel() {
      return this.includeSelectAll ? this.$options.i18n.selectAllLabel : '';
    },
    text() {
      return renderMultiSelectText({
        selected: this.selected,
        items: this.items,
        itemTypeName: this.itemTypeName,
      });
    },
    itemsKeys() {
      return Object.keys(this.items);
    },
  },
  methods: {
    setSelected(items) {
      this.selected = [...items];
      this.$emit('input', this.selected);
    },
  },
  i18n: {
    multipleSelectedLabel: s__(
      'PolicyRuleMultiSelect|%{firstLabel} +%{numberOfAdditionalLabels} more',
    ),
    clearAllLabel: s__('PolicyRuleMultiSelect|Clear all'),
    selectAllLabel: s__('PolicyRuleMultiSelect|Select all'),
    selectedItemsLabel: s__('PolicyRuleMultiSelect|Select %{itemTypeName}'),
    selectPolicyListboxHeader: s__('PolicyRuleMultiSelect|Select %{itemTypeName}'),
    allSelectedLabel: s__('PolicyRuleMultiSelect|All %{itemTypeName}'),
  },
};
</script>

<template>
  <gl-collapsible-listbox
    multiple
    :header-text="listBoxHeader"
    :items="listBoxItems"
    :selected="selected"
    :show-select-all-button-label="selectAllLabel"
    :reset-button-label="$options.i18n.clearAllLabel"
    :toggle-text="text"
    @reset="setSelected([])"
    @select="setSelected"
    @select-all="setSelected(itemsKeys)"
  >
    <template #list-item="{ item }">
      <gl-truncate :text="item.text" />
    </template>
  </gl-collapsible-listbox>
</template>
