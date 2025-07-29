import { s__ } from '~/locale';

export const AI_CATALOG_ENUM_AGENT = 'AGENT';
export const AI_CATALOG_NAME_AGENT = s__('AICatalog|Agent');

export const AI_CATALOG_ENUM_FLOW = 'FLOW';
export const AI_CATALOG_NAME_FLOW = s__('AICatalog|Flow');

export const TYPENAME_AI_CATALOG_ITEM = 'Ai::Catalog::Item';

export const ENUM_TO_NAME_MAP = {
  [AI_CATALOG_ENUM_AGENT]: AI_CATALOG_NAME_AGENT,
  [AI_CATALOG_ENUM_FLOW]: AI_CATALOG_NAME_FLOW,
};

// Matches backend validations in https://gitlab.com/gitlab-org/gitlab/blob/aa02c3080b316cf0f3b71a992bc5cc5dc8e8bb34/ee/app/models/ai/catalog/item.rb#L10
export const MAX_LENGTH_NAME = 255;
export const MAX_LENGTH_DESCRIPTION = 1024;
export const MAX_LENGTH_PROMPT = 1000000;

export const VISIBILITY_LEVEL_PRIVATE = 0;
export const VISIBILITY_LEVEL_PUBLIC = 20;
