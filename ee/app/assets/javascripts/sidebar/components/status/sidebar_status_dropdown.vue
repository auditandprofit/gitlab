<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { unionBy } from 'lodash';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import { __, s__ } from '~/locale';

export default {
  components: {
    GlCollapsibleListbox,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  apollo: {
    workItemTypes: {
      query: namespaceWorkItemTypesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.workspace?.workItemTypes?.nodes || [];
      },
      skip() {
        return !this.shouldFetch;
      },
      error(error) {
        Sentry.captureException(error);
        this.$emit(
          'error',
          s__('WorkItem|Something went wrong when fetching status. Please try again.'),
        );
      },
    },
  },
  data() {
    return {
      workItemTypes: [],
      selectedValue: undefined,
      searchTerm: '',
      shouldFetch: false,
    };
  },
  computed: {
    listItems() {
      let allowedStatus = [];
      this.workItemTypes?.forEach((type) => {
        const statusWidget = type.widgetDefinitions.find(
          (widget) => widget.type === WIDGET_TYPE_STATUS,
        );
        if (statusWidget) {
          /** union by unique ids, since all supported work item types may have the same system
           * defined or custom statuses
           */
          allowedStatus = unionBy(statusWidget.allowedStatuses, allowedStatus, 'id');
        }
      });
      if (this.searchTerm) {
        allowedStatus = fuzzaldrinPlus.filter(allowedStatus, this.searchTerm, {
          key: ['name'],
        });
      }
      return allowedStatus.map((status) => ({
        ...status,
        value: status.id,
        text: status.name,
      }));
    },
    isLoading() {
      return this.$apollo.queries.workItemTypes.loading;
    },
    dropdownText() {
      const selected = this.listItems.find((option) => option.value === this.selectedValue);
      return selected?.text || __('Select status');
    },
  },
  methods: {
    onSearch(value) {
      this.searchTerm = value;
    },
    handleReset() {
      this.selectedValue = undefined;
    },
    onDropdownHide() {
      this.onSearch('');
      this.$refs.listbox.$refs.searchBox.clearInput();
    },
  },
};
</script>

<template>
  <div>
    <input type="hidden" name="update[status]" :value="selectedValue" />
    <gl-collapsible-listbox
      id="bulk_sidebar_status_dropdown"
      ref="listbox"
      v-model="selectedValue"
      :searching="isLoading"
      :searchable="true"
      :header-text="__('Select status')"
      :reset-button-label="__('Reset')"
      :toggle-text="dropdownText"
      block
      is-check-centered
      :items="listItems"
      @shown="shouldFetch = true"
      @hidden="onDropdownHide"
      @search="onSearch"
      @reset="handleReset"
    >
      <template #list-item="{ item }">
        <slot name="list-item" :item="item">{{ item.text }}</slot>
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
