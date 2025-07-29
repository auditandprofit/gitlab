<script>
import { isEmpty } from 'lodash';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { fetchPolicies } from '~/lib/graphql';
import { getParameterByName, removeParams, updateHistory } from '~/lib/utils/url_utility';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import { AI_CATALOG_SHOW_QUERY_PARAM, AI_CATALOG_AGENTS_EDIT_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    GlAlert,
    AiCatalogList,
    AiCatalogItemDrawer,
  },
  apollo: {
    aiCatalogAgents: {
      query: aiCatalogAgentsQuery,
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data.aiCatalogItems.nodes,
      result() {
        this.checkDrawerParams();
      },
    },
  },
  data() {
    return {
      aiCatalogAgents: [],
      activeItem: null,
      errorMessage: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgents.loading;
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
    async deleteAgent(id) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogAgentMutation,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogAgentsQuery],
        });

        if (!data.aiCatalogAgentDelete.success) {
          this.errorMessage = sprintf(s__('AICatalog|Failed to delete agent. %{error}'), {
            error: data.aiCatalogAgentDelete.errors?.[0],
          });
          return;
        }

        this.$toast.show(s__('AICatalog|Agent deleted successfully.'));
      } catch (error) {
        this.errorMessage = sprintf(s__('AICatalog|Failed to delete agent. %{error}'), { error });
        Sentry.captureException(error);
      }
    },
    checkDrawerParams() {
      const urlItemId = getParameterByName(AI_CATALOG_SHOW_QUERY_PARAM);
      if (urlItemId) {
        // TODO: Fetch agent details from the API: https://gitlab.com/gitlab-org/gitlab/-/issues/557201
        this.activeItem =
          this.aiCatalogAgents.find((item) => this.formatId(item.id).toString() === urlItemId) ||
          null;
      } else {
        this.activeItem = null;
      }
    },
  },
  editRoute: AI_CATALOG_AGENTS_EDIT_ROUTE,
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorMessage"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      @dismiss="errorMessage = null"
      >{{ errorMessage }}
    </gl-alert>

    <ai-catalog-list
      :is-loading="isLoading"
      :items="aiCatalogAgents"
      :delete-confirm-title="s__('AICatalog|Delete agent')"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to delete agent %{name}?')"
      :delete-fn="deleteAgent"
      @select-item="selectItem"
    />
    <ai-catalog-item-drawer
      :is-open="isItemSelected"
      :active-item="activeItem"
      :edit-route="$options.editRoute"
      @close="closeDrawer"
    />
  </div>
</template>
