import Vue from 'vue';
import VueRouter from 'vue-router';
import { joinPaths } from '~/lib/utils/url_utility';
import NewSelfHostedModel from 'ee/ai/duo_self_hosted/self_hosted_models/components/new_self_hosted_model.vue';
import EditSelfHostedModel from 'ee/ai/duo_self_hosted/self_hosted_models/components/edit_self_hosted_model.vue';
import DuoSelfHostedApp from 'ee/ai/duo_self_hosted/app.vue';
import { SELF_HOSTED_DUO_TABS, SELF_HOSTED_ROUTE_NAMES } from 'ee/ai/duo_self_hosted/constants';

Vue.use(VueRouter);

export default function createRouter(base) {
  const router = new VueRouter({
    mode: 'history',
    base: joinPaths(gon.relative_url_root || '', base),
    routes: [
      {
        name: SELF_HOSTED_ROUTE_NAMES.INDEX,
        path: '/',
        component: DuoSelfHostedApp,
      },
      {
        name: SELF_HOSTED_ROUTE_NAMES.NEW,
        path: '/models/new',
        component: NewSelfHostedModel,
      },
      {
        name: SELF_HOSTED_ROUTE_NAMES.EDIT,
        path: '/models/:id/edit',
        component: EditSelfHostedModel,
        props: ({ params: { id } }) => {
          return { modelId: Number(id) };
        },
      },
      {
        name: SELF_HOSTED_ROUTE_NAMES.FEATURES,
        path: '/features',
        component: DuoSelfHostedApp,
        props: () => ({ tabId: SELF_HOSTED_DUO_TABS.AI_FEATURE_SETTINGS }),
      },
      {
        name: SELF_HOSTED_ROUTE_NAMES.MODELS,
        path: '/models',
        component: DuoSelfHostedApp,
        props: () => ({ tabId: SELF_HOSTED_DUO_TABS.SELF_HOSTED_MODELS }),
      },
      {
        path: '*',
        redirect: '/',
      },
    ],
  });

  return router;
}
