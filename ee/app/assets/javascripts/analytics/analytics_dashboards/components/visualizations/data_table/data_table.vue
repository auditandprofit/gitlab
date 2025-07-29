<script>
import { GlIcon, GlLink, GlTableLite, GlKeysetPagination } from '@gitlab/ui';

import { __ } from '~/locale';
import { isExternal } from '~/lib/utils/url_utility';

import { formatVisualizationValue } from '../utils';

export default {
  name: 'DataTable',
  components: {
    GlIcon,
    GlLink,
    GlTableLite,
    GlKeysetPagination,
    AssigneeAvatars: () => import('./assignee_avatars.vue'),
    DiffLineChanges: () => import('./diff_line_changes.vue'),
    MergeRequestLink: () => import('./merge_request_link.vue'),
    ChangePercentageIndicator: () => import('./change_percentage_indicator.vue'),
    MetricLabel: () => import('./metric_label.vue'),
    TrendLine: () => import('./trend_line.vue'),
  },
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    nodes() {
      return this.data.nodes || [];
    },
    pageInfo() {
      return this.data.pageInfo || {};
    },
    derivedFields() {
      // NOTE: we derive the field names from the keys in the first row of data
      // unless a custom field config is passed in the visualization options
      if (this.nodes.length < 1) {
        return null;
      }

      return Object.keys(this.nodes[0]).map((key) => ({
        key,
        tdClass: 'gl-truncate gl-max-w-0',
      }));
    },
    fields() {
      return this.options.fields || this.derivedFields;
    },
    showPaginationControls() {
      return Boolean(this.pageInfo.hasPreviousPage || this.pageInfo.hasNextPage);
    },
  },
  methods: {
    isLink(value) {
      return Boolean(value?.text && value?.href);
    },
    isExternalLink(href) {
      return isExternal(href);
    },
    formatVisualizationValue,
    nextPage() {
      const { endCursor } = this.pageInfo;
      this.$emit('updateQuery', {
        pagination: {
          nextPageCursor: endCursor,
        },
      });
    },
    prevPage() {
      const { startCursor } = this.pageInfo;
      this.$emit('updateQuery', {
        pagination: {
          prevPageCursor: startCursor,
        },
      });
    },
  },
  i18n: {
    externalLink: __('external link'),
  },
};
</script>

<template>
  <div>
    <gl-table-lite :fields="fields" :items="nodes" hover responsive class="gl-mt-4">
      <template #cell()="{ value, field }">
        <component :is="field.component" v-if="field.component" v-bind="value" />
        <gl-link v-else-if="isLink(value)" :href="value.href"
          >{{ formatVisualizationValue(value.text) }}
          <gl-icon
            v-if="isExternalLink(value.href)"
            name="external-link"
            :size="12"
            :aria-label="$options.i18n.externalLink"
            class="gl-ml-1"
          />
        </gl-link>
        <template v-else>
          {{ formatVisualizationValue(value) }}
        </template>
      </template>
    </gl-table-lite>
    <gl-keyset-pagination
      v-if="showPaginationControls"
      class="gl-m-3 gl-flex gl-items-center gl-justify-center"
      v-bind="pageInfo"
      @prev="prevPage"
      @next="nextPage"
    />
  </div>
</template>
