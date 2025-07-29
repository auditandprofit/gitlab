import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import createStore from '../stores';
import mrEditModule from '../stores/modules/mr_edit';
import MrEditApp from './app.vue';

export default function mountApprovalInput(el) {
  if (!el) {
    return null;
  }

  const targetBranchTitle = document.querySelector('#js-target-branch-title');
  const targetBranch =
    targetBranchTitle?.dataset?.branchName ||
    targetBranchTitle?.textContent ||
    document.querySelector('#merge_request_target_branch')?.value;

  const store = createStore(
    { approvals: mrEditModule() },
    {
      ...el.dataset,
      prefix: 'mr-edit',
      canEdit: parseBoolean(el.dataset.canEdit),
      canUpdateApprovers: parseBoolean(el.dataset.canUpdateApprovers),
      showCodeOwnerTip: parseBoolean(el.dataset.showCodeOwnerTip),
      allowMultiRule: parseBoolean(el.dataset.allowMultiRule),
      canOverride: parseBoolean(el.dataset.canOverride),
    },
  );

  store.dispatch('setTargetBranch', targetBranch);

  return new Vue({
    el,
    store,
    apolloProvider: new VueApollo({
      defaultClient: createDefaultClient(),
    }),
    render(h) {
      return h(MrEditApp);
    },
  });
}
