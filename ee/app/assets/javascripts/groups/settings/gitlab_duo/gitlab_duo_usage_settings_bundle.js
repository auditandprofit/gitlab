import Vue from 'vue';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import { parseProvideData } from 'ee/usage_quotas/code_suggestions/tab_metadata';

export function initGitLabDuoUsageSettings() {
  const el = document.getElementById('js-gitlab-duo-usage-settings');

  if (!el) return false;

  return new Vue({
    el,
    name: 'GitLabDuoUsageSettings',
    apolloProvider,
    provide: parseProvideData(el),
    render(createElement) {
      return createElement(CodeSuggestionsUsage);
    },
  });
}
