import Vue from 'vue';
import apolloProvider from './graphql/provider';
import App from './components/app.vue';

export default () => {
  const el = document.querySelector('#js-group-security-inventory');
  if (!el) {
    return null;
  }
  if (!el) {
    return null;
  }

  const { groupFullPath, groupName, newProjectPath } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      groupFullPath,
      groupName,
      newProjectPath,
    },
    render(createElement) {
      return createElement(App);
    },
  });
};
