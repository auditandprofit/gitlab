import Vue from 'vue';
import VueRouter from 'vue-router';
import AiCatalogAgents from '../pages/ai_catalog_agents.vue';
import AiCatalogAgent from '../pages/ai_catalog_agent.vue';
import AiCatalogAgentsEdit from '../pages/ai_catalog_agents_edit.vue';
import AiCatalogAgentsRun from '../pages/ai_catalog_agents_run.vue';
import AiCatalogAgentsNew from '../pages/ai_catalog_agents_new.vue';
import AiCatalogFlows from '../pages/ai_catalog_flows.vue';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from './constants';

Vue.use(VueRouter);

export const createRouter = (base) => {
  return new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        name: AI_CATALOG_INDEX_ROUTE,
        path: '',
        component: AiCatalogAgents,
      },
      {
        name: AI_CATALOG_AGENTS_ROUTE,
        path: '/agents',
        component: AiCatalogAgents,
      },
      {
        name: AI_CATALOG_AGENTS_NEW_ROUTE,
        path: '/agents/new',
        component: AiCatalogAgentsNew,
      },
      // Catch-all route for /agents/:id - redirect to /agents?show=:id
      {
        path: '/agents/:id',
        redirect: (to) => ({
          path: '/agents',
          query: { [AI_CATALOG_SHOW_QUERY_PARAM]: to.params.id },
        }),
      },
      {
        path: '/agents/:id',
        component: AiCatalogAgent,
        children: [
          {
            name: AI_CATALOG_AGENTS_EDIT_ROUTE,
            path: 'edit',
            component: AiCatalogAgentsEdit,
          },
          {
            name: AI_CATALOG_AGENTS_RUN_ROUTE,
            path: 'run',
            component: AiCatalogAgentsRun,
          },
        ],
      },
      {
        name: AI_CATALOG_FLOWS_ROUTE,
        path: '/flows',
        component: AiCatalogFlows,
      },
    ],
  });
};
