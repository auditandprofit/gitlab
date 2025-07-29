import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { getCookie } from '~/lib/utils/common_utils';
import { DUO_AGENTIC_MODE_COOKIE } from 'ee/ai/tanuki_bot/constants';
import TanukiBotChatApp from './components/app.vue';
import store from './store';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initTanukiBotChatDrawer = () => {
  const el = document.getElementById('js-tanuki-bot-chat-app');

  if (!el) {
    return false;
  }

  const { userId, resourceId, projectId, chatTitle, rootNamespaceId, agenticAvailable } =
    el.dataset;

  const toggleEls = document.querySelectorAll('.js-tanuki-bot-chat-toggle');
  if (toggleEls.length) {
    toggleEls.forEach((toggleEl) => {
      toggleEl.addEventListener('click', () => {
        if (getCookie(DUO_AGENTIC_MODE_COOKIE) === 'true' && agenticAvailable === 'true') {
          duoChatGlobalState.isAgenticChatShown = !duoChatGlobalState.isAgenticChatShown;
          duoChatGlobalState.isShown = false;
        } else {
          duoChatGlobalState.isShown = !duoChatGlobalState.isShown;
          duoChatGlobalState.isAgenticChatShown = false;
        }
      });
    });
  }

  return new Vue({
    el,
    store: store(),
    apolloProvider,
    render(createElement) {
      return createElement(TanukiBotChatApp, {
        props: {
          userId,
          resourceId,
          projectId,
          chatTitle,
          rootNamespaceId,
          agenticAvailable: JSON.parse(agenticAvailable),
        },
      });
    },
  });
};
