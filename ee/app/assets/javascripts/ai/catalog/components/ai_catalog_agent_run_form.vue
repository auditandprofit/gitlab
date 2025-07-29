<script>
import { uniqueId } from 'lodash';
import { GlButton, GlForm, GlFormFields, GlFormTextarea } from '@gitlab/ui';
import { s__ } from '~/locale';
import { MAX_LENGTH_PROMPT } from 'ee/ai/catalog/constants';
import { createFieldValidators } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';

export default {
  name: 'AiCatalogAgentRunForm',
  components: {
    AiCatalogFormButtons,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormTextarea,
  },
  props: {
    isSubmitting: {
      type: Boolean,
      required: false,
      default: false,
    },
    aiCatalogAgent: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      formValues: {
        userPrompt: this.aiCatalogAgent.latestVersion?.userPrompt,
      },
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-agent-run-form-');
    },
  },
  methods: {
    onSubmit() {
      this.$emit('submit', this.formValues);
    },
  },
  fields: {
    userPrompt: {
      label: s__('AICatalog|User Prompt'),
      validators: createFieldValidators({
        requiredLabel: s__('AICatalog|User Prompt is required.'),
        maxLength: MAX_LENGTH_PROMPT,
      }),
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|Provide instructions or context that will be included for this run.',
        ),
      },
    },
  },
};
</script>

<template>
  <gl-form :id="formId" @submit.prevent="onSubmit">
    <gl-form-fields v-model="formValues" :form-id="formId" :fields="$options.fields">
      <template #input(userPrompt)="{ id, input, value, blur, validation }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :placeholder="
            s__(
              'AICatalog|Please consider my background in... When explaining concepts, use... My preferred format for responses is... Always include...',
            )
          "
          :rows="10"
          :state="validation.state"
          :value="value"
          data-testid="agent-run-form-user-prompt"
          @blur="blur"
          @update="input"
        />
      </template>
    </gl-form-fields>
    <ai-catalog-form-buttons :is-disabled="isSubmitting">
      <gl-button
        class="js-no-auto-disable"
        type="submit"
        variant="confirm"
        category="primary"
        data-testid="agent-run-form-submit-button"
        :loading="isSubmitting"
      >
        <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
        {{ s__('AICatalog|Run') }} (Coming soon)
      </gl-button>
    </ai-catalog-form-buttons>
  </gl-form>
</template>
