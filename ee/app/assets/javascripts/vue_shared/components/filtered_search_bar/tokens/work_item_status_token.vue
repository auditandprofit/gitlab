<script>
import { GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';
import { unionBy } from 'lodash';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__, sprintf } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import { TOKEN_TITLE_STATUS } from '~/vue_shared/components/filtered_search_bar/constants';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';

export default {
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
    GlIcon,
  },
  props: {
    active: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      options: [],
      loading: true,
      hasStartedQuery: false,
    };
  },
  computed: {},
  methods: {
    getActiveOption(options, data) {
      return options.find((option) => option.name === data);
    },
    async fetchStatusesForNamespace() {
      if (!this.config.fullPath) {
        return;
      }

      this.hasStartedQuery = true;

      this.loading = true;

      await this.$apollo
        .query({
          query: namespaceWorkItemTypesQuery,
          variables: {
            fullPath: this.config.fullPath,
          },
        })
        .then(({ data }) => {
          let allowedStatus = [];
          data?.workspace?.workItemTypes?.nodes.forEach((type) => {
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

          this.options = allowedStatus.map((status) => ({
            ...status,
            value: getIdFromGraphQLId(status.id),
          }));
        })
        .catch((error) => {
          const message = sprintf(
            s__(
              'WorkItemStatus|Options could not be loaded for field: %{dropdownLabel}. Please try again.',
            ),
            {
              dropdownLabel: TOKEN_TITLE_STATUS,
            },
          );

          createAlert({
            message,
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.loading = false;
        });
    },
    getOptionText(option) {
      return option.name;
    },
  },
};
</script>

<template>
  <base-token
    :active="active"
    :config="config"
    :value="value"
    :suggestions="options"
    :suggestions-loading="loading"
    :get-active-token-value="getActiveOption"
    :value-identifier="getOptionText"
    @fetch-suggestions="fetchStatusesForNamespace"
    v-on="$listeners"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      <div class="gl-truncate">
        <template v-if="activeTokenValue">
          <gl-icon
            :name="activeTokenValue.iconName"
            :size="12"
            class="gl-mb-[-1px] gl-mr-1 gl-mt-1"
            :style="{ color: activeTokenValue.color }"
          />
          <span>{{ activeTokenValue.name }}</span>
        </template>
        <template v-else>
          {{ inputValue }}
        </template>
      </div>
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="option in suggestions"
        :key="option.id"
        :value="option.name"
      >
        <gl-icon
          :name="option.iconName"
          :size="12"
          class="gl-mr-2"
          :style="{ color: option.color }"
        />
        <span>{{ getOptionText(option) }}</span>
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
