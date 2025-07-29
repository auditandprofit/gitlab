import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import EnableDuoBannerSM from 'ee/ai/components/enable_duo_banner_sm.vue';

Vue.use(VueApollo);

export default function initEnableDuoBannerSM() {
  const el = document.querySelector('.js-enable-duo-banner-sm');

  if (!el) {
    return false;
  }

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const { bannerTitle, calloutsFeatureName, licenseTier } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      bannerTitle,
      calloutsFeatureName,
      licenseTier,
    },
    render: (createElement) => createElement(EnableDuoBannerSM),
  });
}
