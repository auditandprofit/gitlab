export const SELF_HOSTED_MODEL_MUTATIONS = {
  CREATE: 'aiSelfHostedModelCreate',
  UPDATE: 'aiSelfHostedModelUpdate',
};

export const SELF_HOSTED_MODEL_PLATFORMS = {
  API: 'api',
  BEDROCK: 'bedrock',
};

// Temporary dummy endpoint for bedrock models
export const BEDROCK_DUMMY_ENDPOINT = 'http://bedrockselfhostedmodel.com';

// These are model identifiers that should not be translated as they are proper names
/* eslint-disable @gitlab/require-i18n-strings */
export const CLOUD_PROVIDER_MODELS = {
  GPT: 'GPT',
  CLAUDE_3: 'CLAUDE_3',
};
/* eslint-enable @gitlab/require-i18n-strings */
