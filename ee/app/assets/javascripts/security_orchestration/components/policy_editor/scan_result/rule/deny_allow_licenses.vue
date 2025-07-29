<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import { s__, __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { searchInItemsProperties } from '~/lib/utils/search_utils';

export default {
  i18n: {
    selectedLabel: __('Selected'),
    licenses: __('Licenses'),
    header: s__('ScanResultPolicy|Choose a license'),
  },
  name: 'DenyAllowLicenses',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    selected: {
      type: Object,
      required: false,
      default: undefined,
    },
    alreadySelectedLicenses: {
      type: Array,
      required: false,
      default: () => [],
    },
    allLicenses: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    allSelected() {
      const deduplicatedSelection = [...new Set(this.getMappedItemsFromSelectedValues('text'))];
      return this.allLicenses.length === deduplicatedSelection.length;
    },
    unselectedLicenses() {
      const items = this.allLicenses.filter(
        ({ value }) => !this.getMappedItemsFromSelectedValues('value').includes(value),
      );

      return searchInItemsProperties({
        items,
        properties: ['text'],
        searchQuery: this.searchTerm,
      });
    },
    licenses() {
      const groups = [];

      if (!this.allSelected) {
        groups.unshift({
          text: this.$options.i18n.licenses,
          options: this.unselectedLicenses.filter(({ value }) => value !== this.selected?.value),
        });
      }

      if (this.selected) {
        groups.unshift({
          text: this.$options.i18n.selectedLabel,
          options: [this.selected],
        });
      }

      return groups;
    },
    selectedItem() {
      return this.selected?.value || '';
    },
    toggleText() {
      return this.selected?.text || this.$options.i18n.header;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    getMappedItemsFromSelectedValues(key) {
      return this.alreadySelectedLicenses.map((item) => item[key]).filter(Boolean);
    },
    selectLicense(id) {
      const license = this.allLicenses.find((item) => item.value === id);
      this.$emit('select', license);
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    class="gl-max-w-30"
    :header-text="$options.i18n.header"
    :items="licenses"
    :toggle-text="toggleText"
    :selected="selectedItem"
    size="small"
    searchable
    @search="debouncedSearch"
    @select="selectLicense"
  />
</template>
