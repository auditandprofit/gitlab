<script>
import { isEmpty } from 'lodash';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import { getParameterByName, removeParams, updateHistory } from '~/lib/utils/url_utility';
import aiCatalogFlowsQuery from '../graphql/queries/ai_catalog_flows.query.graphql';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import { AI_CATALOG_SHOW_QUERY_PARAM, AI_CATALOG_FLOWS_EDIT_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogFlows',
  components: {
    AiCatalogList,
    AiCatalogItemDrawer,
  },
  apollo: {
    aiCatalogFlows: {
      query: aiCatalogFlowsQuery,
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data.aiCatalogItems.nodes,
      result() {
        this.checkDrawerParams();
      },
    },
  },
  data() {
    return {
      aiCatalogFlows: [],
      activeItem: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogFlows.loading;
    },
    isItemSelected() {
      return !isEmpty(this.activeItem);
    },
  },
  watch: {
    '$route.params.show': {
      handler() {
        this.checkDrawerParams();
      },
    },
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
    closeDrawer() {
      this.activeItem = null;
      updateHistory({
        url: removeParams([AI_CATALOG_SHOW_QUERY_PARAM]),
      });
    },
    selectItem(item) {
      this.activeItem = item;
    },
    checkDrawerParams() {
      const urlItemId = getParameterByName(AI_CATALOG_SHOW_QUERY_PARAM);
      if (urlItemId) {
        // TODO: Fetch flow details from the API: https://gitlab.com/gitlab-org/gitlab/-/issues/557201
        this.activeItem =
          this.aiCatalogFlows?.find((item) => this.formatId(item.id).toString() === urlItemId) ||
          null;
      } else {
        this.activeItem = null;
      }
    },
  },
  editRoute: AI_CATALOG_FLOWS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <ai-catalog-list :is-loading="isLoading" :items="aiCatalogFlows" @select-item="selectItem" />
    <ai-catalog-item-drawer
      :is-open="isItemSelected"
      :active-item="activeItem"
      :edit-route="$options.editRoute"
      @close="closeDrawer"
    />
  </div>
</template>
