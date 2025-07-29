import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { getGraphqlClient } from 'ee/geo_replicable/utils';
import GeoReplicableItemApp from './components/app.vue';

export const initGeoReplicableItem = () => {
  const el = document.getElementById('js-geo-replicable-item');
  const { replicableItemId, geoCurrentSiteId, geoTargetSiteId } = el.dataset;

  const replicableClass = convertObjectPropsToCamelCase(JSON.parse(el.dataset.replicableClassData));

  const apolloProvider = new VueApollo({
    defaultClient: getGraphqlClient(geoCurrentSiteId, geoTargetSiteId),
  });

  return new Vue({
    el,
    apolloProvider,
    render(createElement) {
      return createElement(GeoReplicableItemApp, {
        props: {
          replicableItemId,
          replicableClass,
        },
      });
    },
  });
};
