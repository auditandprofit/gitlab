import { __ } from '~/locale';
import { isAbsolute, isValidURL } from '~/lib/utils/url_utility';
import getProductAnalyticsProjectSettings from 'ee/product_analytics/graphql/queries/get_product_analytics_project_settings.query.graphql';
import {
  FORM_FIELD_CUBE_API_BASE_URL,
  FORM_FIELD_CUBE_API_KEY,
  FORM_FIELD_PRODUCT_ANALYTICS_CONFIGURATOR_CONNECTION_STRING,
  FORM_FIELD_PRODUCT_ANALYTICS_DATA_COLLECTOR_HOST,
} from 'ee/product_analytics/onboarding/components/providers/constants';

export function projectSettingsValidator(prop) {
  const expected = [
    FORM_FIELD_PRODUCT_ANALYTICS_CONFIGURATOR_CONNECTION_STRING,
    FORM_FIELD_PRODUCT_ANALYTICS_DATA_COLLECTOR_HOST,
    FORM_FIELD_CUBE_API_BASE_URL,
    FORM_FIELD_CUBE_API_KEY,
  ];

  return (
    Object.keys(prop).length === expected.length &&
    expected.every((key) => key in prop && (typeof prop[key] === 'string' || prop[key] === null))
  );
}

export function getProjectSettingsValidationErrors(formValues) {
  const errors = {};

  const requiresUrl = [
    FORM_FIELD_PRODUCT_ANALYTICS_CONFIGURATOR_CONNECTION_STRING,
    FORM_FIELD_PRODUCT_ANALYTICS_DATA_COLLECTOR_HOST,
    FORM_FIELD_CUBE_API_BASE_URL,
  ];
  for (const key of requiresUrl) {
    if (formValues[key] && (!isValidURL(formValues[key]) || !isAbsolute(formValues[key]))) {
      errors[key] = __('Enter a valid URL');
    }
  }

  const required = [
    FORM_FIELD_PRODUCT_ANALYTICS_CONFIGURATOR_CONNECTION_STRING,
    FORM_FIELD_PRODUCT_ANALYTICS_DATA_COLLECTOR_HOST,
    FORM_FIELD_CUBE_API_BASE_URL,
    FORM_FIELD_CUBE_API_KEY,
  ];
  for (const key of required) {
    if (!formValues[key]) {
      errors[key] = __('This field is required');
    }
  }

  return errors;
}

export function updateProjectSettingsApolloCache(apolloStore, projectPath, updatedProjectSettings) {
  const cacheData = apolloStore.readQuery({
    query: getProductAnalyticsProjectSettings,
    variables: { projectPath },
  });

  apolloStore.writeQuery({
    query: getProductAnalyticsProjectSettings,
    variables: { projectPath },
    data: {
      ...cacheData,
      project: {
        ...cacheData.project,
        productAnalyticsSettings: {
          ...cacheData.project.productAnalyticsSettings,
          ...updatedProjectSettings,
        },
      },
    },
  });
}
