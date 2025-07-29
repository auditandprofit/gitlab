import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import NestedRouteApp from '../nested_route_app.vue';
import AgentsPlatformIndex from '../pages/index/duo_agents_platform_index.vue';
import AgentsPlatformShow from '../pages/show/duo_agents_platform_show.vue';
import AgentsPlatformNew from '../pages/new/duo_agents_platform_new.vue';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_NEW_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
  WORKFLOW_END_PAGE_LINK,
} from './constants';

Vue.use(VueRouter);

export const createRouter = (base) => {
  return new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        component: NestedRouteApp,
        path: '/agent-sessions',
        meta: {
          text: s__('DuoAgentsPlatform|Agent sessions'),
        },
        children: [
          {
            name: AGENTS_PLATFORM_INDEX_ROUTE,
            path: '',
            component: AgentsPlatformIndex,
          },
          {
            name: AGENTS_PLATFORM_NEW_ROUTE,
            path: 'new',
            component: AgentsPlatformNew,
            meta: {
              text: s__('DuoAgentsPlatform|New'),
            },
          },
          // TODO: Remove when https://gitlab.com/gitlab-org/duo-ui/-/issues/83 is done
          // Maps the workflow_end message type to the platform new page
          {
            name: WORKFLOW_END_PAGE_LINK,
            path: 'new',
            component: AgentsPlatformNew,
            meta: {
              text: s__('DuoAgentsPlatform|New'),
            },
          },
          {
            name: AGENTS_PLATFORM_SHOW_ROUTE,
            path: ':id(\\d+)',
            component: AgentsPlatformShow,
          },
        ],
      },
      // /automate route is currently empty, so we can't redirect there
      { path: '*', redirect: '/agent-sessions' },
    ],
  });
};
