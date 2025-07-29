import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import { parseProvideData } from 'ee/usage_quotas/code_suggestions/tab_metadata';

export function initGitLabDuoHome() {
  const el = document.getElementById('js-gitlab-duo-home');

  if (!el) return false;

  return new Vue({
    el,
    name: 'GitlabDuoHome',
    apolloProvider,
    provide() {
      const data = el.dataset;

      return {
        ...parseProvideData(el),
        modelSwitchingEnabled: parseBoolean(data.modelSwitchingEnabled),
        modelSwitchingPath: data.modelSwitchingPath,
        duoSeatUtilizationPath: data.duoSeatUtilizationPath,
        duoConfigurationPath: data.duoConfigurationPath,
        duoAvailability: data.duoAvailability,
        experimentFeaturesEnabled: parseBoolean(data.experimentFeaturesEnabled),
        promptCacheEnabled: parseBoolean(data.promptCacheEnabled),
        areExperimentSettingsAllowed: parseBoolean(data.areExperimentSettingsAllowed),
        arePromptCacheSettingsAllowed: parseBoolean(data.arePromptCacheSettingsAllowed),
        areDuoCoreFeaturesEnabled: parseBoolean(data.areDuoCoreFeaturesEnabled),
      };
    },
    render(createElement) {
      return createElement(GitlabDuoHome);
    },
  });
}
