import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';

import { parseBoolean } from '~/lib/utils/common_utils';
import { defaultClient } from '~/graphql_shared/issuable_client';

import RelatedItemsTreeApp from './components/related_items_tree_app.vue';
import TreeItem from './components/tree_item.vue';
import TreeRoot from './components/tree_root.vue';
import createStore from './store';

Vue.use(Vuex);
Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-tree');

  if (!el) {
    return false;
  }

  const apolloProvider = new VueApollo({
    defaultClient,
  });

  const {
    id,
    iid,
    numericalId,
    fullPath,
    groupId,
    groupName,
    autoCompleteEpics,
    autoCompleteIssues,
    userSignedIn,
    allowIssuableHealthStatus,
    allowScopedLabels,
    allowSubEpics,
    type,
  } = el.dataset;
  const initialData = JSON.parse(el.dataset.initial);
  const roadmapAppData = JSON.parse(el.dataset.roadmapAppData);

  Vue.component('TreeRoot', TreeRoot);
  Vue.component('TreeItem', TreeItem);

  return new Vue({
    el,
    name: 'RelatedItemsTreeRoot',
    store: createStore(),
    apolloProvider,
    components: { RelatedItemsTreeApp },
    provide: {
      roadmapAppData,
    },
    created() {
      this.setInitialParentItem({
        fullPath,
        type,
        numericalId: parseInt(numericalId, 10),
        groupId: parseInt(groupId, 10),
        groupName,
        id,
        iid: parseInt(iid, 10),
        title: initialData.initialTitleText,
        confidential: initialData.confidential,
        reference: `${initialData.fullPath}${initialData.issuableRef}`,
        userPermissions: {
          canAdmin: initialData.canAdmin,
          canAdminRelation: initialData.canAdminRelation,
          canReadRelation: initialData.canReadRelation,
        },
      });

      this.setInitialConfig({
        issuesEndpoint: initialData.issueLinksEndpoint,
        projectsEndpoint: initialData.projectsEndpoint,
        autoCompleteEpics: parseBoolean(autoCompleteEpics),
        autoCompleteIssues: parseBoolean(autoCompleteIssues),
        userSignedIn: parseBoolean(userSignedIn),
        allowIssuableHealthStatus: parseBoolean(allowIssuableHealthStatus),
        allowScopedLabels: parseBoolean(allowScopedLabels),
        allowSubEpics: parseBoolean(allowSubEpics),
        epicsWebUrl: initialData.epicsWebUrl,
        issuesWebUrl: initialData.issuesWebUrl,
      });
    },
    methods: {
      ...Vuex.mapActions(['setInitialParentItem', 'setInitialConfig']),
    },
    render: (createElement) => createElement('related-items-tree-app'),
  });
};
