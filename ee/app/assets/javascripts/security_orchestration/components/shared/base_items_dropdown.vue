<script>
import { GlCollapsibleListbox, GlTruncate } from '@gitlab/ui';
import { uniqBy } from 'lodash';
import { __ } from '~/locale';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';

export default {
  i18n: {
    clearAllLabel: __('Clear all'),
    selectAllLabel: __('Select all'),
  },
  name: 'BaseItemsDropdown',
  components: {
    GlCollapsibleListbox,
    GlTruncate,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    category: {
      type: String,
      required: false,
      default: 'primary',
    },
    variant: {
      type: String,
      required: false,
      default: 'default',
    },
    items: {
      type: Array,
      required: true,
      default: () => [],
    },
    headerText: {
      type: String,
      required: false,
      default: '',
    },
    selected: {
      type: [Array, String],
      required: false,
      default: () => [],
    },
    searching: {
      type: Boolean,
      required: false,
      default: false,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    placement: {
      type: String,
      required: false,
      default: 'bottom-start',
    },
    multiple: {
      type: Boolean,
      required: false,
      default: true,
    },
    infiniteScroll: {
      type: Boolean,
      required: false,
      default: false,
    },
    itemTypeName: {
      type: String,
      required: false,
      default: __('projects'),
    },
  },
  data() {
    return {
      initialCollection: this.items,
    };
  },
  computed: {
    formattedSelectedIds() {
      const idArray = this.multiple ? this.selected : [this.selected];
      // Allow selected ids to be strings or numbers so that the toggle text is correct
      return idArray.map((item) => item.toString());
    },
    itemsIds() {
      return this.items.map(({ value }) => value);
    },
    labelItems() {
      return this.initialCollection?.reduce((acc, { value, text }) => {
        acc[value] = text;
        return acc;
      }, {});
    },
    dropdownPlaceholder() {
      return renderMultiSelectText({
        selected: this.formattedSelectedIds,
        items: this.labelItems,
        itemTypeName: this.itemTypeName,
        useAllSelected: !this.infiniteScroll,
      });
    },
    resetButtonLabel() {
      return this.multiple ? this.$options.i18n.clearAllLabel : '';
    },
  },
  watch: {
    /**
     * In order to preserve selected toggle text
     * when searched text should be created from
     * initial and not filtered collection
     * @param newCollection
     */
    items(newCollection) {
      this.initialCollection = uniqBy([...this.initialCollection, ...newCollection], 'value');
    },
  },
  methods: {
    setSearchTerm(value) {
      this.$emit('search', value.trim());
    },
    reset() {
      this.$emit('reset');
    },
    selectItems(items) {
      this.$emit('select', items);
    },
    selectAllItems() {
      this.$emit('select-all', this.itemsIds);
    },
    bottomReached() {
      this.$emit('bottom-reached');
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    is-check-centered
    searchable
    fluid-width
    :category="category"
    :variant="variant"
    :disabled="disabled"
    :items="items"
    :infinite-scroll="infiniteScroll"
    :infinite-scroll-loading="loading"
    :header-text="headerText"
    :multiple="multiple"
    :loading="loading"
    :searching="searching"
    :selected="selected"
    :placement="placement"
    :toggle-text="dropdownPlaceholder"
    :reset-button-label="resetButtonLabel"
    :show-select-all-button-label="$options.i18n.selectAllLabel"
    @bottom-reached="bottomReached"
    @search="setSearchTerm"
    @reset="reset"
    @select="selectItems"
    @select-all="selectAllItems"
  >
    <template #list-item="{ item }">
      <span :class="['gl-block', { 'gl-font-bold': item.fullPath }]">
        <gl-truncate :text="item.text" with-tooltip />
      </span>
      <span v-if="item.fullPath" class="gl-mt-1 gl-block gl-text-sm gl-text-subtle">
        <gl-truncate position="middle" :text="item.fullPath" with-tooltip />
      </span>
    </template>
  </gl-collapsible-listbox>
</template>
