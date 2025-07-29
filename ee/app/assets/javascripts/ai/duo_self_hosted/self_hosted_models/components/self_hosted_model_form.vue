<script>
import {
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlForm,
  GlFormFields,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/dist/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { s__, __, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import InputCopyToggleVisibility from '~/vue_shared/components/input_copy_toggle_visibility/input_copy_toggle_visibility.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import {
  SELF_HOSTED_MODEL_PLATFORMS,
  BEDROCK_DUMMY_ENDPOINT,
  CLOUD_PROVIDER_MODELS,
} from '../constants';
import { RELEASE_STATES } from '../../constants';
import TestConnectionButton from './test_connection_button.vue';

const bedrockIdentifierPrefix = 'bedrock/';
const isBedrockModelIdentifier = (identifier) => identifier.startsWith(bedrockIdentifierPrefix);
const baseFormFieldClasses = ['gl-bg-subtle', 'gl-w-full', 'gl-p-6', 'gl-pb-2', 'gl-m-0'];
const baseFormFields = {
  name: {
    label: s__('AdminSelfHostedModels|Deployment name'),
    validators: [
      formValidators.required(s__('AdminSelfHostedModels|Please enter a deployment name.')),
    ],
  },
  platform: {
    label: s__('AdminSelfHostedModels|Platform'),
  },
  model: {
    label: s__('AdminSelfHostedModels|Model family'),
    validators: [formValidators.required(s__('AdminSelfHostedModels|Please select a model.'))],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
};
const apiFormFields = {
  endpoint: {
    label: s__('AdminSelfHostedModels|Endpoint'),
    validators: [formValidators.required(s__('AdminSelfHostedModels|Please enter an endpoint.'))],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
  identifier: {
    label: s__('AdminSelfHostedModels|Model identifier'),
    validators: [
      formValidators.required(s__('AdminSelfHostedModels|Please enter a model identifier.')),
      formValidators.factory(
        s__('AdminSelfHostedModels|Model identifier must be less than 255 characters.'),
        (val) => val.length <= 255,
      ),
    ],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
};
const bedrockFormFields = {
  identifier: {
    label: s__('AdminSelfHostedModels|Model identifier'),
    validators: [
      formValidators.required(s__('AdminSelfHostedModels|Please enter a model identifier.')),
      formValidators.factory(
        sprintf(
          s__(
            'AdminSelfHostedModels|Model identifier must start with "%{bedrockIdentifierPrefix}"',
          ),
          { bedrockIdentifierPrefix },
        ),
        (val) => isBedrockModelIdentifier(val),
      ),
      formValidators.factory(
        s__('AdminSelfHostedModels|Model identifier must be less than 255 characters.'),
        (val) => val.length <= 255,
      ),
    ],
    groupAttrs: {
      class: baseFormFieldClasses,
    },
  },
};

export default {
  name: 'SelfHostedModelForm',
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlForm,
    GlFormFields,
    GlLink,
    GlSprintf,
    InputCopyToggleVisibility,
    ModelSelectDropdown,
    TestConnectionButton,
  },
  inject: ['basePath', 'modelOptions', 'betaModelsEnabled', 'duoConfigurationSettingsPath'],
  props: {
    submitButtonText: {
      type: String,
      required: false,
      default: s__('AdminSelfHostedModels|Create self-hosted model'),
    },
    mutationData: {
      type: Object,
      required: true,
    },
    initialFormValues: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  i18n: {
    defaultError: s__(
      'AdminSelfHostedModels|There was an error saving the self-hosted model. Please try again.',
    ),
    nonUniqueDeploymentNameError: s__(
      'AdminSelfHostedModels|Please enter a unique deployment name.',
    ),
    invalidEndpointError: s__('AdminSelfHostedModels|Please add a valid endpoint.'),
    successMessage: s__('AdminSelfHostedModels|The self-hosted model was successfully %{action}.'),
    awsSetupMessage: s__(
      'AdminSelfHostedModels|To fully set up AWS credentials for this model please refer to the %{linkStart}AWS Bedrock Configuration Guide%{linkEnd}',
    ),
    betaModelsAvailableMessage: s__(
      'AdminSelfHostedModels|More models are available in beta. You can %{linkStart}turn on self-hosted model beta features%{linkEnd}.',
    ),
  },
  formId: 'self-hosted-model-form',
  platforms: [
    {
      text: __('API'),
      value: SELF_HOSTED_MODEL_PLATFORMS.API,
    },
    {
      text: s__('AdminSelfHostedModels|Amazon Bedrock'),
      value: SELF_HOSTED_MODEL_PLATFORMS.BEDROCK,
    },
  ],
  awsSetupUrl: helpPagePath(
    'administration/gitlab_duo_self_hosted/supported_llm_serving_platforms',
    {
      anchor: 'for-cloud-hosted-model-deployments',
    },
  ),
  baseFormFieldClasses,
  data() {
    const {
      id = '',
      name = '',
      model = '',
      endpoint = '',
      identifier = '',
      apiToken = '',
    } = this.initialFormValues;

    /*
      When an identifier starts with "bedrock/", we can infer it to be a bedrock model.
      This is only a workaround for going GA in 17.9 - as a more permanent solution this value should
      be stored and read from the DB https://gitlab.com/gitlab-org/gitlab/-/issues/507967
    */
    const platform =
      id !== '' && isBedrockModelIdentifier(identifier)
        ? SELF_HOSTED_MODEL_PLATFORMS.BEDROCK
        : SELF_HOSTED_MODEL_PLATFORMS.API;

    return {
      baseFormValues: {
        name,
        endpoint,
        identifier,
        model: model.toUpperCase(),
      },
      platform,
      apiToken,
      serverValidations: {},
      isSaving: false,
    };
  },
  computed: {
    availableModels() {
      const gaModels = this.modelOptions.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.GA,
      );
      const betaModels = this.modelOptions.filter(
        ({ releaseState }) => releaseState === RELEASE_STATES.BETA,
      );

      // sort model options by releaseState
      return [...gaModels, ...betaModels].map(({ modelValue, modelName, releaseState }) => ({
        value: modelValue,
        text: modelName,
        releaseState,
      }));
    },
    selectedModel() {
      return this.availableModels.find(({ value }) => value === this.baseFormValues.model);
    },
    formFields() {
      const platformFields = this.isApiPlatform ? apiFormFields : bedrockFormFields;
      const fields = {
        ...baseFormFields,
        ...platformFields,
      };

      fields.identifier.inputAttrs = {
        placeholder: this.identifierPlaceholder,
      };

      return fields;
    },
    hasValidInput() {
      const { name, model, endpoint, identifier } = this.baseFormValues;

      if (name === '' || model === '' || identifier === '') {
        return false;
      }

      if (this.isApiPlatform) {
        return endpoint !== '' && identifier.length <= 255;
      }

      return isBedrockModelIdentifier(identifier) && identifier.length <= 255;
    },
    isEditing() {
      return Boolean(this.initialFormValues.id);
    },
    isApiPlatform() {
      return this.platform === SELF_HOSTED_MODEL_PLATFORMS.API;
    },
    successMessage() {
      return sprintf(this.$options.i18n.successMessage, {
        action: this.isEditing ? 'saved' : 'created',
      });
    },
    formValues() {
      /*
        Endpoint and api tokens aren't used for Bedrock models. There is currently a non-null constraint
        on the endpoint column so so we still need to send a placeholder. This is a workaround for
        going GA in 17.9 - the columns should be made nullable as a more permanent solution.
        https://gitlab.com/gitlab-org/gitlab/-/issues/507966
      */
      if (!this.isApiPlatform) {
        return {
          ...this.baseFormValues,
          endpoint: BEDROCK_DUMMY_ENDPOINT,
          apiToken: '',
        };
      }

      return {
        apiToken: this.apiToken,
        ...this.baseFormValues,
      };
    },
    identifierPlaceholder() {
      if (this.platform === SELF_HOSTED_MODEL_PLATFORMS.BEDROCK) {
        return 'bedrock/';
      }

      const { model } = this.baseFormValues;
      if (model && !Object.values(CLOUD_PROVIDER_MODELS).includes(model)) {
        return 'custom_openai/';
      }

      return '';
    },
    identifierLabelDescription() {
      let identifierLabel = 'provider/model-name';
      if (this.identifierPlaceholder.length > 0) {
        identifierLabel = `${this.identifierPlaceholder}model-name`;
      }

      return sprintf(
        s__('AdminSelfHostedModels|Provide the model identifier in the form of %{identifierLabel}'),
        { identifierLabel },
      );
    },
  },
  methods: {
    async onSubmit() {
      if (!this.hasValidInput) return;

      const { mutation } = this.mutationData;

      const mutationInput = {
        ...this.formValues,
        ...(this.isEditing
          ? {
              id: convertToGraphQLId('Ai::SelfHostedModel', this.initialFormValues.id),
            }
          : {}),
      };

      this.isSaving = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation,
          variables: {
            input: {
              ...mutationInput,
            },
          },
        });
        if (data) {
          const { errors } = data[this.mutationData.name];
          if (errors.length > 0) {
            this.onError(errors);
            this.isSaving = false;
            return;
          }

          this.isSaving = false;
          visitUrlWithAlerts(this.basePath, [
            {
              message: this.successMessage,
              variant: 'success',
            },
          ]);
        }
      } catch (error) {
        createAlert({
          message: this.$options.i18n.defaultError,
          error,
          captureError: true,
        });
        this.isSaving = false;
      }
    },
    onSelect(selectedModelValue) {
      this.onInputField({ name: 'model' });
      this.baseFormValues.model = selectedModelValue;
    },
    // clears the validation error
    onInputField({ name }) {
      delete this.serverValidations[name];
    },
    onClick(event) {
      event.currentTarget.blur();
    },
    onError(errors) {
      // TODO: Delegate sorting of errors to the back-end - the client should only need to consume these
      const error = errors[0];
      const SERVER_VALIDATION_ERRORS = {
        /* eslint-disable @gitlab/require-i18n-strings */
        name: 'Name has already been taken',
        endpoint: 'Endpoint is blocked',
        /* eslint-enable @gitlab/require-i18n-strings */
      };

      if (error.includes(SERVER_VALIDATION_ERRORS.endpoint)) {
        this.serverValidations = {
          ...this.serverValidations,
          endpoint: this.$options.i18n.invalidEndpointError,
        };
      }
      if (error.includes(SERVER_VALIDATION_ERRORS.name)) {
        this.serverValidations = {
          ...this.serverValidations,
          name: this.$options.i18n.nonUniqueDeploymentNameError,
        };
      }

      // Unrecognised error, display generic error message
      if (
        !error.includes(SERVER_VALIDATION_ERRORS.name) &&
        !error.includes(SERVER_VALIDATION_ERRORS.endpoint)
      ) {
        throw new Error(error);
      }
    },
  },
};
</script>
<template>
  <gl-form :id="$options.formId" class="gl-max-w-62" @submit.prevent="onSubmit">
    <gl-form-fields
      :key="`${platform}-form-fields`"
      v-model="baseFormValues"
      :fields="formFields"
      :form-id="$options.formId"
      :server-validations="serverValidations"
      @input-field="onInputField"
      @submit="$emit('submit', baseFormValues)"
    >
      <template #group(name)-label-description>
        {{ s__('AdminSelfHostedModels|A unique and descriptive name for your deployment.') }}
      </template>

      <template #input(platform)>
        <gl-collapsible-listbox
          v-model="platform"
          data-testid="platform-dropdown-selector"
          :items="$options.platforms"
          :toggle-text="platform.text"
          block
        />
      </template>

      <template #after(platform)>
        <div v-if="!betaModelsEnabled" class="gl-pb-6 gl-pt-3">
          <gl-alert variant="info" :dismissible="false">
            <gl-sprintf :message="$options.i18n.betaModelsAvailableMessage">
              <template #link="{ content }">
                <gl-link
                  data-testid="duo-configuration-link"
                  :href="duoConfigurationSettingsPath"
                  >{{ content }}</gl-link
                >
              </template>
            </gl-sprintf>
          </gl-alert>
        </div>
      </template>

      <template #group(model)-label-description>
        {{
          s__(
            'AdminSelfHostedModels|Select an appropriate model family from the list of approved GitLab models.',
          )
        }}
      </template>
      <template #input(model)>
        <model-select-dropdown
          :selected-option="selectedModel"
          :items="availableModels"
          :placeholder-dropdown-text="s__('AdminSelfHostedModels|Select model')"
          :is-loading="isSaving"
          @select="onSelect"
        />
      </template>

      <template #group(endpoint)-label-description>
        {{
          s__(
            'AdminSelfHostedModels|Specify the URL endpoint where your self-hosted model is accessible',
          )
        }}
      </template>

      <template #group(identifier)-label-description>
        {{ identifierLabelDescription }}
      </template>
    </gl-form-fields>
    <div :class="[...$options.baseFormFieldClasses, 'gl-pb-6']">
      <input-copy-toggle-visibility
        v-if="isApiPlatform"
        v-model="apiToken"
        :value="apiToken"
        :label="s__('AdminSelfHostedModels|API Key (optional)')"
        :initial-visibility="false"
        :disabled="isSaving"
        :show-copy-button="false"
        :label-description="
          s__(
            'AdminSelfHostedModels|If required, provide the API token that grants access to your self-hosted model deployment.',
          )
        "
      />
      <gl-sprintf v-else :message="$options.i18n.awsSetupMessage">
        <template #link="{ content }">
          <gl-link :href="$options.awsSetupUrl" target="_blank">{{ content }} </gl-link>
        </template>
      </gl-sprintf>
    </div>
    <div class="gl-pt-6">
      <gl-button
        type="submit"
        variant="confirm"
        class="js-no-auto-disable gl-mr-2"
        :loading="isSaving"
        @click="onClick"
      >
        {{ submitButtonText }}
      </gl-button>
      <test-connection-button
        class="gl-mr-2"
        :disabled="!hasValidInput"
        :connection-test-input="formValues"
      />
      <gl-button :href="basePath">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </gl-form>
</template>
