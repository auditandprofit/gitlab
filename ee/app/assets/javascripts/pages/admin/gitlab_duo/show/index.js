import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import initEnableDuoBannerSM from 'ee/ai/init_enable_duo_banner_sm';

export function mountGitlabDuoHomeApp() {
  const el = document.getElementById('js-gitlab-duo-admin-page');

  if (!el) {
    return null;
  }

  const {
    addDuoProSeatsUrl,
    aiGatewayUrl,
    duoSeatUtilizationPath,
    enabledExpandedLogging,
    isBulkAddOnAssignmentEnabled,
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    duoConfigurationPath,
    duoSelfHostedPath,
    duoAvailability,
    directCodeSuggestionsEnabled,
    experimentFeaturesEnabled,
    promptCacheEnabled,
    betaSelfHostedModelsEnabled,
    areExperimentSettingsAllowed,
    arePromptCacheSettingsAllowed,
    duoAddOnStartDate,
    duoAddOnEndDate,
    amazonQReady,
    amazonQAutoReviewEnabled,
    amazonQConfigurationPath,
    canManageSelfHostedModels,
    areDuoCoreFeaturesEnabled,
    duoWorkflowEnabled,
    duoWorkflowServiceAccount,
    isSaas,
    duoWorkflowSettingsPath,
    redirectPath,
    duoWorkflowDisablePath,
  } = el.dataset;

  return new Vue({
    el,
    name: 'GitlabDuoHome',
    apolloProvider,
    provide: {
      aiGatewayUrl,
      isSaaS: parseBoolean(isSaas),
      addDuoProHref: addDuoProSeatsUrl,
      duoSeatUtilizationPath,
      isBulkAddOnAssignmentEnabled: parseBoolean(isBulkAddOnAssignmentEnabled),
      subscriptionName,
      subscriptionStartDate,
      subscriptionEndDate,
      duoConfigurationPath,
      duoSelfHostedPath,
      duoAvailability,
      directCodeSuggestionsEnabled: parseBoolean(directCodeSuggestionsEnabled),
      expandedLoggingEnabled: parseBoolean(enabledExpandedLogging),
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      promptCacheEnabled: parseBoolean(promptCacheEnabled),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      arePromptCacheSettingsAllowed: parseBoolean(arePromptCacheSettingsAllowed),
      duoAddOnStartDate,
      duoAddOnEndDate,
      amazonQReady: parseBoolean(amazonQReady),
      amazonQAutoReviewEnabled: parseBoolean(amazonQAutoReviewEnabled),
      amazonQConfigurationPath,
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      areDuoCoreFeaturesEnabled: parseBoolean(areDuoCoreFeaturesEnabled),
      duoWorkflowEnabled: parseBoolean(duoWorkflowEnabled),
      duoWorkflowServiceAccount: duoWorkflowServiceAccount
        ? JSON.parse(duoWorkflowServiceAccount)
        : undefined,
      duoWorkflowSettingsPath,
      redirectPath,
      duoWorkflowDisablePath,
      showDuoWorkflowSettings: true,
    },
    render: (h) => h(GitlabDuoHome),
  });
}

mountGitlabDuoHomeApp();
initEnableDuoBannerSM();
