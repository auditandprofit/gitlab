import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initAiSettings = (id, component) => {
  const el = document.getElementById(id);

  if (!el) {
    return false;
  }

  const {
    aiGatewayUrl,
    canManageSelfHostedModels,
    cascadingSettingsData,
    duoAvailability,
    areDuoSettingsLocked,
    experimentFeaturesEnabled,
    duoCoreFeaturesEnabled,
    promptCacheEnabled,
    redirectPath,
    updateId,
    duoProVisible,
    disabledDirectConnectionMethod,
    showEarlyAccessBanner,
    earlyAccessPath,
    betaSelfHostedModelsEnabled,
    toggleBetaModelsPath,
    amazonQAvailable,
    amazonQAutoReviewEnabled,
    onGeneralSettingsPage,
    areExperimentSettingsAllowed,
    arePromptCacheSettingsAllowed,
    enabledExpandedLogging,
    duoChatExpirationDays,
    duoChatExpirationColumn,
    duoWorkflowMcpEnabled,
    duoWorkflowAvailable,
    isSaas,
  } = el.dataset;

  let cascadingSettingsDataParsed;
  try {
    cascadingSettingsDataParsed = convertObjectPropsToCamelCase(JSON.parse(cascadingSettingsData), {
      deep: true,
    });
  } catch {
    cascadingSettingsDataParsed = null;
  }

  return new Vue({
    el,
    apolloProvider,
    provide: {
      aiGatewayUrl,
      canManageSelfHostedModels: parseBoolean(canManageSelfHostedModels),
      cascadingSettingsData: cascadingSettingsDataParsed,
      areDuoSettingsLocked: parseBoolean(areDuoSettingsLocked),
      duoAvailability,
      experimentFeaturesEnabled: parseBoolean(experimentFeaturesEnabled),
      duoCoreFeaturesEnabled: parseBoolean(duoCoreFeaturesEnabled),
      promptCacheEnabled: parseBoolean(promptCacheEnabled),
      disabledDirectConnectionMethod: parseBoolean(disabledDirectConnectionMethod),
      showEarlyAccessBanner: parseBoolean(showEarlyAccessBanner),
      duoWorkflowMcpEnabled: parseBoolean(duoWorkflowMcpEnabled),
      duoWorkflowAvailable: parseBoolean(duoWorkflowAvailable),
      betaSelfHostedModelsEnabled: parseBoolean(betaSelfHostedModelsEnabled),
      toggleBetaModelsPath,
      enabledExpandedLogging: parseBoolean(enabledExpandedLogging),
      earlyAccessPath,
      amazonQAvailable: parseBoolean(amazonQAvailable),
      amazonQAutoReviewEnabled: parseBoolean(amazonQAutoReviewEnabled),
      onGeneralSettingsPage: parseBoolean(onGeneralSettingsPage),
      areExperimentSettingsAllowed: parseBoolean(areExperimentSettingsAllowed),
      arePromptCacheSettingsAllowed: parseBoolean(arePromptCacheSettingsAllowed),
      duoChatExpirationDays: parseInt(duoChatExpirationDays, 10),
      duoChatExpirationColumn,
      isSaaS: parseBoolean(isSaas),
    },
    render: (createElement) =>
      createElement(component, {
        props: {
          redirectPath,
          updateId,
          duoProVisible: parseBoolean(duoProVisible),
        },
      }),
  });
};
