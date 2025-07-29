<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import { TYPENAME_AI_CATALOG_ITEM } from '../constants';

export default {
  name: 'AiCatalogAgent',
  components: {
    GlEmptyState,
    GlLoadingIcon,
  },
  data() {
    return {
      aiCatalogAgent: {},
    };
  },
  apollo: {
    aiCatalogAgent: {
      query: aiCatalogAgentQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
        };
      },
      update(data) {
        return data?.aiCatalogItem || {};
      },
      error(error) {
        createAlert({
          message: error.message,
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgent.loading;
    },
    agentNotFound() {
      return this.aiCatalogAgent && Object.keys(this.aiCatalogAgent).length === 0;
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />

    <gl-empty-state
      v-else-if="agentNotFound"
      :title="s__('AiCatalog|Agent not found.')"
      :svg-path="$options.emptySearchSvg"
    />

    <router-view v-else :ai-catalog-agent="aiCatalogAgent" />
  </div>
</template>
