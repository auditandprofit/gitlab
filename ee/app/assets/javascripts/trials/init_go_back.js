import Vue from 'vue';
import VueRouter from 'vue-router';
import GoBack from 'ee/trials/components/go_back.vue';

Vue.use(VueRouter);

export default function initializeGoBack() {
  const el = document.querySelector('.js-go-back');

  if (!el) {
    return false;
  }

  const routes = [{ path: '/', name: 'root' }];
  const router = new VueRouter({
    routes,
    base: '/',
    mode: 'history',
  });

  return new Vue({
    el,
    name: 'GoBack',
    router,
    render: (createElement) => createElement(GoBack),
  });
}
