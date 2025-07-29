import Vue from 'vue';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import App from './components/app.vue';

export default function init() {
  const el = document.querySelector('#js-secret-detection-configuration');

  if (!el) {
    return undefined;
  }

  const { projectFullPath } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      projectFullPath,
    },
    render(createElement) {
      return createElement(App);
    },
  });
}
