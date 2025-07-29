<script>
import { GlAlert, GlButton, GlFormInput, GlFormGroup } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import InputCopyToggleVisibility from '~/vue_shared/components/input_copy_toggle_visibility/input_copy_toggle_visibility.vue';
import productAnalyticsProjectSettingsUpdate from 'ee/product_analytics/graphql/mutations/product_analytics_project_settings_update.mutation.graphql';
import {
  FORM_FIELD_CUBE_API_BASE_URL,
  FORM_FIELD_CUBE_API_KEY,
  FORM_FIELD_PRODUCT_ANALYTICS_CONFIGURATOR_CONNECTION_STRING,
  FORM_FIELD_PRODUCT_ANALYTICS_DATA_COLLECTOR_HOST,
} from './constants';
import {
  getProjectSettingsValidationErrors,
  projectSettingsValidator,
  updateProjectSettingsApolloCache,
} from './utils';

export default {
  name: 'ProviderSettingsForm',
  components: { GlAlert, GlButton, GlFormInput, GlFormGroup, InputCopyToggleVisibility },
  inject: ['namespaceFullPath'],
  props: {
    projectSettings: {
      type: Object,
      required: true,
      validator: projectSettingsValidator,
    },
  },
  data() {
    return {
      isLoading: false,
      submitted: false,
      hasApiError: false,
      modifiedProjectSettings: {
        productAnalyticsConfiguratorConnectionString: '',
        productAnalyticsDataCollectorHost: '',
        cubeApiBaseUrl: '',
        cubeApiKey: '',
        ...this.projectSettings,
      },
    };
  },
  computed: {
    configuratorConnectionStringInputProps() {
      return {
        state: this.getInputState(FORM_FIELD_PRODUCT_ANALYTICS_CONFIGURATOR_CONNECTION_STRING),
      };
    },
    cubeApiKeyInputProps() {
      return {
        state: this.getInputState(FORM_FIELD_CUBE_API_KEY),
      };
    },
    hasValidationErrors() {
      return Object.values(this.validationErrors).some(Boolean);
    },
    validationErrors() {
      return getProjectSettingsValidationErrors(this.modifiedProjectSettings);
    },
  },
  methods: {
    async onFormSubmit() {
      this.hasApiError = false;
      this.submitted = true;
      if (this.hasValidationErrors) {
        return;
      }

      this.isLoading = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: productAnalyticsProjectSettingsUpdate,
          variables: {
            fullPath: this.namespaceFullPath,
            ...this.modifiedProjectSettings,
          },
          update: (store) => {
            updateProjectSettingsApolloCache(
              store,
              this.namespaceFullPath,
              this.modifiedProjectSettings,
            );
          },
        });

        const { errors } = data.productAnalyticsProjectSettingsUpdate;

        if (errors?.length) {
          this.hasApiError = true;
          return;
        }

        this.$emit('saved');
      } catch (error) {
        this.hasApiError = true;
        Sentry.captureException(error);
      } finally {
        this.isLoading = false;
      }
    },
    getInputState(property) {
      if (!this.submitted) {
        return null;
      }

      return !this.validationErrors[property];
    },
  },
  FORM_FIELD_PRODUCT_ANALYTICS_DATA_COLLECTOR_HOST,
  FORM_FIELD_CUBE_API_BASE_URL,
};
</script>
<template>
  <form @submit.prevent="onFormSubmit">
    <gl-alert
      v-if="hasApiError"
      :dismissible="false"
      variant="danger"
      class="gl-mb-5"
      data-testid="clear-project-level-settings-confirmation-modal-error"
    >
      {{ s__('Analytics|Failed to update project-level settings. Please try again.') }}
    </gl-alert>

    <p>
      {{ s__('ProductAnalytics|Override the instance analytics configuration for this project.') }}
    </p>

    <input-copy-toggle-visibility
      v-model="modifiedProjectSettings.productAnalyticsConfiguratorConnectionString"
      data-testid="configurator-connection-string-input"
      :label="s__('ProductAnalytics|Configurator connection string')"
      :show-copy-button="false"
      :initial-visibility="!modifiedProjectSettings.productAnalyticsConfiguratorConnectionString"
      :description="s__('ProductAnalytics|The connection string for your configurator instance.')"
      :optional="false"
      :disabled="isLoading"
      :form-input-group-props="configuratorConnectionStringInputProps"
      :invalid-feedback="validationErrors.productAnalyticsConfiguratorConnectionString"
    />

    <gl-form-group
      :optional="false"
      data-testid="collector-host-form-group"
      label-for="collector-host-input"
      label="Collector host"
      description="The host of your data collector instance."
      :invalid-feedback="validationErrors.productAnalyticsDataCollectorHost"
    >
      <gl-form-input
        id="collector-host-input"
        v-model="modifiedProjectSettings.productAnalyticsDataCollectorHost"
        data-testid="collector-host-input"
        :disabled="isLoading"
        :state="getInputState($options.FORM_FIELD_PRODUCT_ANALYTICS_DATA_COLLECTOR_HOST)"
      />
    </gl-form-group>

    <gl-form-group
      :optional="false"
      data-testid="cube-api-url-form-group"
      label-for="cube-api-url-input"
      label="Cube API URL"
      description="The URL of your Cube instance."
      :invalid-feedback="validationErrors.cubeApiBaseUrl"
    >
      <gl-form-input
        id="cube-api-url-input"
        v-model="modifiedProjectSettings.cubeApiBaseUrl"
        data-testid="cube-api-url-input"
        :disabled="isLoading"
        :state="getInputState($options.FORM_FIELD_CUBE_API_BASE_URL)"
      />
    </gl-form-group>

    <input-copy-toggle-visibility
      v-model="modifiedProjectSettings.cubeApiKey"
      data-testid="cube-api-key-input"
      :label="s__('ProductAnalytics|Cube API key')"
      :show-copy-button="false"
      :initial-visibility="!modifiedProjectSettings.cubeApiKey"
      :description="s__('ProductAnalytics|Used to retrieve dashboard data from the Cube instance.')"
      :optional="false"
      :disabled="isLoading"
      :form-input-group-props="cubeApiKeyInputProps"
      :invalid-feedback="validationErrors.cubeApiKey"
    />

    <div class="gl-flex gl-justify-end gl-gap-3">
      <gl-button
        type="button"
        data-testid="cancel-button"
        :disabled="isLoading"
        @click="$emit('canceled')"
        >{{ __('Cancel') }}</gl-button
      >
      <gl-button
        type="button"
        variant="confirm"
        data-testid="submit-button"
        :loading="isLoading"
        :disabled="isLoading"
        @click="onFormSubmit"
        >{{ __('Save changes') }}</gl-button
      >
    </div>
  </form>
</template>
