import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import store from '../tanuki_bot/store';
import DuoAgenticChatApp from './components/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initDuoAgenticChat = () => {
  const el = document.getElementById('js-duo-agentic-chat-app');

  if (!el) {
    return false;
  }

  const { projectId, namespaceId, resourceId, metadata } = el.dataset;

  return new Vue({
    el,
    store: store(),
    apolloProvider,
    render(createElement) {
      return createElement(DuoAgenticChatApp, {
        props: {
          projectId,
          namespaceId,
          resourceId,
          metadata,
        },
      });
    },
  });
};
