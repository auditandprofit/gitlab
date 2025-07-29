/* eslint-disable import/export */
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  getDefaultWorkItemTypes as getDefaultWorkItemTypesCE,
  getTypeTokenOptions as getTypeTokenOptionsCE,
  convertToApiParams as convertToApiParamsCE,
  convertToUrlParams as convertToUrlParamsCE,
} from '~/issues/list/utils';
import { filtersMap, URL_PARAM } from '~/issues/list/constants';
import { __, s__ } from '~/locale';

import {
  OPERATOR_IS,
  TOKEN_TYPE_STATE,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  WORK_ITEM_TYPE_ENUM_EPIC,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_TEST_CASE,
} from '~/work_items/constants';
import {
  TYPENAME_CUSTOM_FIELD,
  TYPENAME_CUSTOM_FIELD_SELECT_OPTION,
} from '~/graphql_shared/constants';

export * from '~/issues/list/utils';

const customFieldApiFieldName = 'customField';

/**
 * Get the types of work items that should be displayed on issues lists.
 * This should be consistent with `Issue::TYPES_FOR_LIST` in the backend.
 *
 * @returns {Array<string>}
 * */
export const getDefaultWorkItemTypes = ({
  hasEpicsFeature,
  hasOkrsFeature,
  hasQualityManagementFeature,
}) => {
  const types = getDefaultWorkItemTypesCE();
  if (hasEpicsFeature) {
    types.push(WORK_ITEM_TYPE_ENUM_EPIC);
  }
  if (hasOkrsFeature) {
    types.push(WORK_ITEM_TYPE_ENUM_KEY_RESULT, WORK_ITEM_TYPE_ENUM_OBJECTIVE);
  }
  if (hasQualityManagementFeature) {
    types.push(WORK_ITEM_TYPE_ENUM_TEST_CASE);
  }
  return types;
};

export const getTypeTokenOptions = ({
  hasEpicsFeature,
  hasOkrsFeature,
  hasQualityManagementFeature,
}) => {
  const options = getTypeTokenOptionsCE();
  if (hasEpicsFeature) {
    options.push({
      icon: 'epic',
      title: __('Epic'),
      value: 'epic',
    });
  }
  if (hasOkrsFeature) {
    options.push(
      { icon: 'issue-type-objective', title: s__('WorkItem|Objective'), value: 'objective' },
      { icon: 'issue-type-keyresult', title: s__('WorkItem|Key Result'), value: 'key_result' },
    );
  }
  if (hasQualityManagementFeature) {
    options.push({
      icon: 'issue-type-test-case',
      title: s__('WorkItem|Test case'),
      value: 'test_case',
    });
  }
  return options;
};

const customFieldRegex = /custom-field\[(\d+)\]/;
const isCustomField = (name) => customFieldRegex.test(name);
const isCustomFieldToken = (token) => customFieldRegex.test(token.type);

const tokenTypes = Object.keys(filtersMap);

const getUrlParams = (tokenType) =>
  Object.values(filtersMap[tokenType][URL_PARAM]).flatMap((filterObj) => Object.values(filterObj));

const urlParamKeys = tokenTypes.flatMap(getUrlParams);

const getTokenTypeFromUrlParamKey = (urlParamKey) => {
  if (isCustomField(urlParamKey)) {
    return urlParamKey;
  }
  return tokenTypes.find((tokenType) => getUrlParams(tokenType).includes(urlParamKey));
};

const getOperatorFromUrlParamKey = (tokenType, urlParamKey) => {
  if (isCustomField(urlParamKey)) {
    return OPERATOR_IS;
  }
  return Object.entries(filtersMap[tokenType][URL_PARAM]).find(([, filterObj]) =>
    Object.values(filterObj).includes(urlParamKey),
  )[0];
};

export const getFilterTokens = (locationSearch, options = {}) =>
  Array.from(new URLSearchParams(locationSearch).entries())
    .filter(([key]) => {
      if (!options.includeStateToken && key === TOKEN_TYPE_STATE) {
        return false;
      }
      const customField = options.hasCustomFieldsFeature && isCustomField(key);
      return urlParamKeys.includes(key) || customField;
    })
    .map(([key, data]) => {
      const type = getTokenTypeFromUrlParamKey(key);
      const operator = getOperatorFromUrlParamKey(type, key);
      return {
        type,
        value: { data, operator },
      };
    });

/**
 * @param {Object} token - Custom field token ex. { type: "custom-field[2]", }
 * @returns {string} - Custom field token id ex. "2"
 */
export const getCustomFieldTokenId = (token) =>
  token?.type?.replace('custom-field[', '').replace(']', '');

/**
 * @param {Object} filterTokensCustomFields - Custom field tokens
 * @returns {Object} - Custom field tokens with duplicated ids merged into one
 */
export const mergeDuplicatedCustomFieldTokens = (filterTokensCustomFields) => {
  return Object.values(
    filterTokensCustomFields.reduce((acc, token) => {
      const customFieldId = getCustomFieldTokenId(token);

      if (!customFieldId) {
        return acc;
      }

      if (acc[customFieldId]) {
        const existingData = Array.isArray(acc[customFieldId].value.data)
          ? acc[customFieldId].value.data
          : [acc[customFieldId].value.data];
        const newData = Array.isArray(token.value.data) ? token.value.data : [token.value.data];

        acc[customFieldId].value.data = [...new Set([...existingData, ...newData])];
      } else {
        acc[customFieldId] = {
          ...token,
          value: {
            ...token.value,
            data: Array.isArray(token.value.data) ? token.value.data : [token.value.data],
          },
        };
      }

      return acc;
    }, {}),
  );
};

export const convertToApiParams = (filterTokens, options = {}) => {
  const params = new Map();
  const filterTokensFoss = filterTokens.filter((t) => !isCustomFieldToken(t));

  if (options.hasCustomFieldsFeature) {
    const filterTokensCustomFields = filterTokens.filter((t) => isCustomFieldToken(t));

    // Merge duplicated custom fields tokens that have the same id/field
    const uniqueFilterTokensCustomFields =
      mergeDuplicatedCustomFieldTokens(filterTokensCustomFields);

    uniqueFilterTokensCustomFields.forEach((token) => {
      const customFieldId = getCustomFieldTokenId(token);

      const isValueArray = Array.isArray(token.value.data);
      // When field type is multi-select, the value will be an array, so we need to get each ID individually
      const selectedOptionIds = isValueArray
        ? token.value.data.map((value) =>
            convertToGraphQLId(TYPENAME_CUSTOM_FIELD_SELECT_OPTION, value),
          )
        : [convertToGraphQLId(TYPENAME_CUSTOM_FIELD_SELECT_OPTION, token.value.data)];

      const data = [
        {
          customFieldId: convertToGraphQLId(TYPENAME_CUSTOM_FIELD, customFieldId),
          selectedOptionIds,
        },
      ];

      params.set(
        customFieldApiFieldName,
        params.has(customFieldApiFieldName)
          ? [params.get(customFieldApiFieldName), data].flat()
          : data,
      );
    });
  }

  return {
    ...convertToApiParamsCE(filterTokensFoss),
    ...Object.fromEntries(params),
  };
};

export const convertToUrlParams = (filterTokens, options = {}) => {
  const params = new Map();

  if (options.hasCustomFieldsFeature) {
    const filterTokensCustomFields = filterTokens.filter((t) => isCustomFieldToken(t));

    filterTokensCustomFields.forEach((token) => {
      const urlParam = token.type;

      params.set(
        urlParam,
        params.has(urlParam) ? [params.get(urlParam), token.value.data].flat() : token.value.data,
      );
    });
  }

  const filterTokensFoss = filterTokens.filter((t) => !isCustomFieldToken(t));
  return {
    ...convertToUrlParamsCE(filterTokensFoss),
    ...Object.fromEntries(params),
  };
};
