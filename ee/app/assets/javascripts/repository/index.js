import Vue from 'vue';
import initTree from '~/repository';
import CodeOwners from '../vue_shared/components/code_owners/code_owners.vue';

const initCodeOwnersApp = (router, apolloProvider, projectPath) => {
  const codeOwnersEl = document.querySelector('#js-code-owners');
  if (!codeOwnersEl) return null;

  const { branch, canViewBranchRules, branchRulesPath } = codeOwnersEl.dataset;
  return new Vue({
    el: codeOwnersEl,
    router,
    apolloProvider,
    render(h) {
      return h(CodeOwners, {
        props: {
          filePath: this.$route.params.path,
          projectPath,
          branch,
          canViewBranchRules,
          branchRulesPath,
        },
      });
    },
  });
};

export default () => {
  const { router, apolloProvider, projectPath } = initTree();

  initCodeOwnersApp(router, apolloProvider, projectPath);
};
