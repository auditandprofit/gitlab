import { s__ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import { createAsyncTabContentWrapper } from '~/usage_quotas/components/async_tab_content_wrapper';
import apolloProvider from '../shared/provider';

export const parseProvideData = (el) => {
  const {
    fullPath,
    groupId,
    duoProTrialHref,
    addDuoProHref,
    duoProBulkUserAssignmentAvailable,
    isStandalonePage,
    isFreeNamespace,
    buySubscriptionPath,
    duoAddOnIsTrial,
    duoAddOnStartDate,
    duoAddOnEndDate,
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    handRaiseLeadGlmContent,
    handRaiseLeadProductInteraction,
    handRaiseLeadButtonAttributes,
    handRaiseLeadCtaTracking,
    duoPagePath,
  } = el.dataset;

  let handRaiseLeadButtonAttributesParsed;
  let handRaiseLeadCtaTrackingParsed;

  try {
    handRaiseLeadButtonAttributesParsed = JSON.parse(handRaiseLeadButtonAttributes);
  } catch {
    handRaiseLeadButtonAttributesParsed = {};
  }

  try {
    handRaiseLeadCtaTrackingParsed = JSON.parse(handRaiseLeadCtaTracking);
  } catch {
    handRaiseLeadCtaTrackingParsed = {};
  }

  return {
    fullPath,
    groupId: parseInt(groupId, 10),
    duoProTrialHref,
    duoAddOnIsTrial: parseBoolean(duoAddOnIsTrial),
    duoAddOnStartDate,
    duoAddOnEndDate,
    addDuoProHref,
    isSaaS: true,
    isStandalonePage: parseBoolean(isStandalonePage),
    isFreeNamespace: parseBoolean(isFreeNamespace),
    buySubscriptionPath,
    isBulkAddOnAssignmentEnabled: parseBoolean(duoProBulkUserAssignmentAvailable),
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    handRaiseLeadData: {
      glmContent: handRaiseLeadGlmContent,
      productInteraction: handRaiseLeadProductInteraction,
      buttonAttributes: handRaiseLeadButtonAttributesParsed,
      ctaTracking: handRaiseLeadCtaTrackingParsed,
    },
    duoPagePath,
  };
};

export const getCodeSuggestionsTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector('#js-code-suggestions-usage-app');

  if (!el) return false;

  const CodeSuggestionsUsage = () => {
    const component = import(
      /* webpackChunkName: 'uq_code_suggestions' */ './components/code_suggestions_usage.vue'
    );
    return createAsyncTabContentWrapper(component);
  };

  const codeSuggestionsTabMetadata = {
    title: s__('UsageQuota|GitLab Duo'),
    hash: '#code-suggestions-usage-tab',
    testid: 'code-suggestions-tab',
    component: {
      name: 'CodeSuggestionsUsageTab',
      apolloProvider,
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(CodeSuggestionsUsage);
      },
    },
    tracking: {
      action: 'click_gitlab_duo_tab_on_usage_quotas',
    },
  };

  if (includeEl) {
    codeSuggestionsTabMetadata.component.el = el;
  }

  return codeSuggestionsTabMetadata;
};
