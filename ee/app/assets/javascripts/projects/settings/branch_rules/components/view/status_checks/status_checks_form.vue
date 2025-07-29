<script>
import { GlButton, GlForm, GlFormGroup, GlFormInput } from '@gitlab/ui';
import { isValidURL } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';

/* eslint-disable @gitlab/require-i18n-strings */
const SERVER_VALIDATION_ERRORS = {
  urlTaken: 'External url has already been taken',
  nameTaken: 'Name has already been taken',
};
/* eslint-enable @gitlab/require-i18n-strings */

export default {
  name: 'StatusCheckForm',
  i18n: {
    serviceNameLabel: s__('StatusChecks|Service name'),
    serviceNameDescription: s__('StatusChecks|Examples: QA, Security, Performance.'),
    apiLabel: s__('StatusChecks|API to check'),
    apiDescription: s__('StatusChecks|Invoke an external API as part of the pipeline process.'),
    nameTaken: s__('StatusCheck|Name already exists.'),
    nameMissing: s__('StatusCheck|Please provide a name.'),
    urlTaken: s__('StatusCheck|External API is already in use.'),
    invalidUrl: s__('StatusCheck|Please provide a valid URL.'),
    saveChanges: __('Save changes'),
    cancel: __('Cancel'),
  },
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
  },
  props: {
    selectedStatusCheck: {
      type: Object,
      required: false,
      default: () => null,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    serverValidationErrors: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    const { name = '', externalUrl = '', id = null } = this.selectedStatusCheck || {};
    return {
      id,
      name,
      externalUrl,
      showValidation: false,
    };
  },
  computed: {
    isValid() {
      return this.isValidName && this.isValidURL;
    },
    isValidName() {
      return Boolean(this.name.trim());
    },
    isValidURL() {
      return isValidURL(this.externalUrl);
    },
    isValidNameState() {
      return this.showValidation
        ? this.isValidName &&
            !this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.nameTaken)
        : true;
    },
    isValidUrlState() {
      return this.showValidation
        ? this.isValidURL &&
            !this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.urlTaken)
        : true;
    },
    invalidNameMessage() {
      if (this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.nameTaken)) {
        return this.$options.i18n.nameTaken;
      }

      return this.$options.i18n.nameMissing;
    },
    invalidUrlMessage() {
      if (this.serverValidationErrors.includes(SERVER_VALIDATION_ERRORS.urlTaken)) {
        return this.$options.i18n.urlTaken;
      }

      return this.$options.i18n.invalidUrl;
    },
  },
  methods: {
    emitSaveEvent() {
      this.showValidation = true;

      if (this.isValid) {
        const { name, externalUrl, id } = this;
        this.$emit('save-status-check-change', { name, externalUrl, id });
      }
    },
  },
  serviceNameInput: 'service-name-input',
  apiUrlInput: 'api-url-input',
  apiPlaceholderText: 'https://api.gitlab.com',
};
</script>

<template>
  <gl-form novalidate @submit.prevent="emitSaveEvent">
    <gl-form-group
      data-testid="service-name-group"
      :label="$options.i18n.serviceNameLabel"
      :label-for="$options.serviceNameInput"
      :description="$options.i18n.serviceNameDescription"
      :state="isValidNameState"
      :invalid-feedback="invalidNameMessage"
      class="gl-border-none"
    >
      <gl-form-input
        :id="$options.serviceNameInput"
        v-model="name"
        data-testid="service-name-input"
      />
    </gl-form-group>

    <gl-form-group
      data-testid="api-url-group"
      :label="$options.i18n.apiLabel"
      :label-for="$options.apiUrlInput"
      :description="$options.i18n.apiDescription"
      :state="isValidUrlState"
      :invalid-feedback="invalidUrlMessage"
      class="gl-border-none"
    >
      <gl-form-input
        :id="$options.apiUrlInput"
        v-model="externalUrl"
        type="url"
        data-testid="api-url-input"
        :placeholder="$options.apiPlaceholderText"
      />
    </gl-form-group>

    <div class="gl-flex gl-gap-3">
      <gl-button
        variant="confirm"
        data-testid="save-btn"
        :loading="isLoading"
        type="submit"
        @click.prevent="emitSaveEvent"
      >
        {{ $options.i18n.saveChanges }}
      </gl-button>
      <gl-button
        variant="confirm"
        data-testid="cancel-btn"
        category="secondary"
        @click="$emit('close-status-check-drawer')"
      >
        {{ $options.i18n.cancel }}
      </gl-button>
    </div>
  </gl-form>
</template>
