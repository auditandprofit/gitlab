import { s__ } from '~/locale';

export const DUO_CORE = 'DUO_CORE';
export const DUO_PRO = 'CODE_SUGGESTIONS';
export const DUO_ENTERPRISE = 'DUO_ENTERPRISE';
export const DUO_SELF_HOSTED = 'DUO_SELF_HOSTED';
export const DUO_AMAZON_Q = 'DUO_AMAZON_Q';

export const DUO_IDENTIFIERS = [DUO_CORE, DUO_PRO, DUO_ENTERPRISE, DUO_SELF_HOSTED, DUO_AMAZON_Q];

export const DUO_TITLES = {
  [DUO_CORE]: s__('CodeSuggestions|GitLab Duo Core'),
  [DUO_PRO]: s__('CodeSuggestions|GitLab Duo Pro'),
  [DUO_ENTERPRISE]: s__('CodeSuggestions|GitLab Duo Enterprise'),
  [DUO_SELF_HOSTED]: s__('CodeSuggestions|GitLab Duo Self-Hosted'),
  [DUO_AMAZON_Q]: s__('AmazonQ|GitLab Duo with Amazon Q'),
};
