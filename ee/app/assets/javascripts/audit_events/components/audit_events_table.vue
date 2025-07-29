<script>
import { GlPagination, GlTable } from '@gitlab/ui';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import { getParameterValues, setUrlParams } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';

import HtmlTableCell from './table_cells/html_table_cell.vue';
import UrlTableCell from './table_cells/url_table_cell.vue';

export default {
  components: {
    HtmlTableCell,
    GlTable,
    GlPagination,
    EmptyResult,
    UrlTableCell,
    UserDate,
  },
  props: {
    events: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLastPage: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      page: parseInt(getParameterValues('page')[0], 10) || 1,
    };
  },
  computed: {
    displayTable() {
      return this.events.length > 0;
    },
    prevPage() {
      return this.page > 1 ? this.page - 1 : null;
    },
    nextPage() {
      return !this.isLastPage ? this.page + 1 : null;
    },
  },
  methods: {
    generateLink(page) {
      return setUrlParams({ page });
    },
  },
  fields: [
    {
      key: 'author',
      label: s__('AuditLogs|Author'),
    },
    {
      key: 'object',
      label: s__('AuditLogs|Object'),
    },
    {
      key: 'action',
      label: s__('AuditLogs|Action'),
    },
    {
      key: 'target',
      label: s__('AuditLogs|Target'),
    },
    {
      key: 'ip_address',
      label: s__('AuditLogs|IP Address'),
    },
    {
      key: 'date',
      label: s__('AuditLogs|Date'),
    },
  ],
  dateTimeFormat: LONG_DATE_FORMAT_WITH_TZ,
};
</script>

<template>
  <div v-if="displayTable" class="audit-log-table" data-testid="audit-log-table">
    <gl-table
      class="gl-table-no-top-border"
      :fields="$options.fields"
      :items="events"
      show-empty
      stacked="md"
    >
      <template #cell(author)="{ value: { url, name } }">
        <url-table-cell :url="url" :name="name" />
      </template>
      <template #cell(object)="{ value: { url, name } }">
        <url-table-cell :url="url" :name="name" />
      </template>
      <template #cell(action)="{ value }">
        <html-table-cell :html="value" />
      </template>
      <template #cell(target)="{ value }">
        <span class="gl-wrap-anywhere">{{ value }}</span>
      </template>
      <template #cell(date)="{ value }">
        <user-date :date="value" :date-format="$options.dateTimeFormat" />
      </template>
    </gl-table>
    <gl-pagination
      v-model="page"
      :prev-page="prevPage"
      :next-page="nextPage"
      :link-gen="generateLink"
      align="center"
      class="gl-w-full"
    />
  </div>
  <empty-result v-else type="filter" />
</template>
