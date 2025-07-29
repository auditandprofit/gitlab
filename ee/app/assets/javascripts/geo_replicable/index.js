import Vue from 'vue';
import Translate from '~/vue_shared/translate';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import GeoReplicableApp from './components/app.vue';
import createStore from './store';
import { formatListboxItems } from './filters';
import { FILTERED_SEARCH_TOKENS } from './constants';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-geo-replicable');
  const { geoCurrentSiteId, geoTargetSiteId, replicableBasePath } = el.dataset;

  const replicableTypes = convertObjectPropsToCamelCase(JSON.parse(el.dataset.replicableTypes), {
    deep: true,
  });

  const {
    titlePlural,
    graphqlFieldName,
    graphqlMutationRegistryClass,
    graphqlRegistryClass,
    verificationEnabled,
  } = convertObjectPropsToCamelCase(JSON.parse(el.dataset.replicatorClassData));

  return new Vue({
    el,
    store: createStore({
      titlePlural,
      graphqlFieldName,
      graphqlMutationRegistryClass,
      verificationEnabled,
      geoCurrentSiteId,
      geoTargetSiteId,
    }),
    provide: {
      replicableBasePath,
      replicableTypes,
      graphqlRegistryClass,
      itemTitle: titlePlural,
      listboxItems: formatListboxItems(replicableTypes),
      filteredSearchTokens: FILTERED_SEARCH_TOKENS,
    },

    render(createElement) {
      return createElement(GeoReplicableApp);
    },
  });
};
