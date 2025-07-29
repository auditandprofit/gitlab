import Vue from 'vue';
import EnableDuoBanner from 'ee/ai/components/enable_duo_banner.vue';

export default function initEnableDuoBannerTrigger() {
  const el = document.querySelector('#js-enable-duo-banner');

  if (!el) {
    return false;
  }

  const { bannerTitle, groupId, groupPlan, calloutsPath, calloutsFeatureName } = el.dataset;

  return new Vue({
    el,
    provide: {
      bannerTitle,
      groupId,
      groupPlan,
      calloutsPath,
      calloutsFeatureName,
    },
    render: (createElement) => createElement(EnableDuoBanner),
  });
}
