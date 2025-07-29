import Vue from 'vue';
import VueRouter from 'vue-router';
import ListAgents from 'ee/ml/ai_agents/views/list_agents.vue';
import ShowAgent from 'ee/ml/ai_agents/views/show_agent.vue';
import CreateAgent from 'ee/ml/ai_agents/views/create_agent.vue';
import EditAgent from 'ee/ml/ai_agents/views/edit_agent.vue';
import {
  ROUTE_LIST_AGENTS,
  ROUTE_NEW_AGENT,
  ROUTE_SHOW_AGENT,
  ROUTE_AGENT_SETTINGS,
} from './constants';

Vue.use(VueRouter);

export default function createRouter(base) {
  const router = new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        name: ROUTE_LIST_AGENTS,
        path: '/',
        component: ListAgents,
      },
      {
        name: ROUTE_NEW_AGENT,
        path: '/new',
        component: CreateAgent,
      },
      {
        name: ROUTE_SHOW_AGENT,
        path: '/:agentId',
        component: ShowAgent,
      },
      {
        name: ROUTE_AGENT_SETTINGS,
        path: '/:agentId/settings',
        component: EditAgent,
      },
    ],
  });

  return router;
}
