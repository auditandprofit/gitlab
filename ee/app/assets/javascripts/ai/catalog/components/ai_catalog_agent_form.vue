<script>
import { uniqueId } from 'lodash';
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormFields,
  GlFormTextarea,
  GlFormRadioGroup,
  GlFormRadio,
  GlIcon,
} from '@gitlab/ui';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  MAX_LENGTH_PROMPT,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';
import { __, s__ } from '~/locale';
import { createFieldValidators } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';

const tmpProjectId = 'gid://gitlab/Project/1000000';

export default {
  components: {
    AiCatalogFormButtons,
    GlAlert,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormRadioGroup,
    GlFormRadio,
    GlFormTextarea,
    GlIcon,
  },
  props: {
    mode: {
      type: String,
      required: true,
      validator: (mode) => ['edit', 'create'].includes(mode),
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    errorMessages: {
      type: Array,
      required: false,
      default: () => [],
    },
    initialValues: {
      type: Object,
      required: false,
      default() {
        return {
          projectId: tmpProjectId,
          name: '',
          description: '',
          systemPrompt: '',
          userPrompt: '',
          public: false,
        };
      },
    },
  },
  data() {
    return {
      formValues: {
        ...this.initialValues,
        visibilityLevel: this.initialValues.public
          ? VISIBILITY_LEVEL_PUBLIC
          : VISIBILITY_LEVEL_PRIVATE,
      },
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-agent-form-');
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    submitButtonText() {
      return this.isEditMode ? s__('AICatalog|Save changes') : s__('AICatalog|Create agent');
    },
    visibilityLevels() {
      return [
        {
          value: VISIBILITY_LEVEL_PRIVATE,
          label: s__('AICatalog|Private'),
          text: s__(
            'AICatalog|Only developers, maintainers and owners of this project can view and use the agent. Only maintainers and owners  of this project can edit or delete the agent.',
          ),
          icon: 'lock',
        },
        {
          value: VISIBILITY_LEVEL_PUBLIC,
          label: s__('AICatalog|Public'),
          text: s__(
            'AICatalog|Anyone can view and use the agent without authorization. Only maintainers and owners of this project can edit or delete the agent.',
          ),
          icon: 'earth',
        },
      ];
    },
    visibilityLevelAlertText() {
      if (
        this.isEditMode &&
        this.initialValues.public &&
        this.formValues.visibilityLevel === VISIBILITY_LEVEL_PRIVATE
      ) {
        return s__('AICatalog|This agent can be made private if it is not used.');
      }

      if (
        !this.initialValues.public &&
        this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC
      ) {
        return s__('AICatalog|A public agent can be made private only if it is not used.');
      }

      return '';
    },
    fields() {
      return {
        projectId: {
          label: s__('AICatalog|Project ID'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Project ID is required.'),
          }),
          inputAttrs: {
            'data-testid': 'agent-form-input-project-id',
            placeholder: tmpProjectId,
            disabled: this.isEditMode,
          },
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Select a project for your AI agent to be associated with.',
            ),
          },
        },
        name: {
          label: __('Name'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Name is required.'),
            maxLength: MAX_LENGTH_NAME,
          }),
          inputAttrs: {
            'data-testid': 'agent-form-input-name',
            placeholder: s__('AICatalog|e.g., Research Assistant, Creative Writer, Code Helper'),
          },
          groupAttrs: {
            labelDescription: s__('AICatalog|Choose a memorable name for your AI agent.'),
          },
        },
        description: {
          label: __('Description'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Description is required.'),
            maxLength: MAX_LENGTH_DESCRIPTION,
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Briefly describe what this agent is designed to do and its key capabilities.',
            ),
          },
        },
        systemPrompt: {
          label: s__('AICatalog|System Prompt'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|System Prompt is required.'),
            maxLength: MAX_LENGTH_PROMPT,
          }),
          groupAttrs: {
            labelDescription: s__(
              "AICatalog|Define the agent's personality, expertise, and behavioral guidelines. This shapes how the agent responds and approaches tasks.",
            ),
          },
        },
        userPrompt: {
          label: s__('AICatalog|User Prompt'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|User Prompt is required.'),
            maxLength: MAX_LENGTH_PROMPT,
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Provide default instructions or context that will be included with every user interaction.',
            ),
          },
        },
        visibilityLevel: {
          label: __('Visibility level'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Visibility level is required.'),
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Choose who can view and interact with this agent after it is published to the public AI catalog.',
            ),
          },
        },
      };
    },
  },
  methods: {
    handleSubmit() {
      const trimmedFormValues = {
        projectId: this.formValues.projectId.trim(),
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        systemPrompt: this.formValues.systemPrompt.trim(),
        userPrompt: this.formValues.userPrompt.trim(),
        public: this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC,
      };
      this.$emit('submit', trimmedFormValues);
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorMessages.length"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      data-testid="agent-form-error-alert"
      @dismiss="$emit('dismiss-error')"
    >
      <span v-if="errorMessages.length === 1">{{ errorMessages[0] }}</span>
      <ul v-else class="!gl-mb-0 gl-pl-5">
        <li v-for="(errorMessage, index) in errorMessages" :key="index">
          {{ errorMessage }}
        </li>
      </ul>
    </gl-alert>
    <gl-form :id="formId" @submit.prevent="">
      <gl-form-fields
        v-model="formValues"
        :form-id="formId"
        :fields="fields"
        @submit="handleSubmit"
      >
        <template #input(description)="{ id, input, value, blur, validation }">
          <gl-form-textarea
            :id="id"
            :no-resize="false"
            :placeholder="
              s__(
                'AICatalog|This agent specializes in... It can help you with... Best suited for...',
              )
            "
            :state="validation.state"
            :value="value"
            data-testid="agent-form-textarea-description"
            @blur="blur"
            @update="input"
          />
        </template>
        <template #input(systemPrompt)="{ id, input, value, blur, validation }">
          <gl-form-textarea
            :id="id"
            :no-resize="false"
            :placeholder="
              s__(
                'AICatalog|You are an expert in [domain]. Your communication style is [style]. When helping users, you should always... Your key strengths include... You approach problems by...',
              )
            "
            :state="validation.state"
            :value="value"
            data-testid="agent-form-textarea-system-prompt"
            @blur="blur"
            @update="input"
          />
        </template>
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
            data-testid="agent-form-textarea-user-prompt"
            @blur="blur"
            @update="input"
          />
        </template>
        <template #input(visibilityLevel)="{ id, input, validation, value }">
          <gl-form-radio-group
            :id="id"
            :state="validation.state"
            :checked="value"
            data-testid="agent-form-radio-group-visibility-level"
            @input="input"
          >
            <gl-form-radio
              v-for="level in visibilityLevels"
              :key="level.value"
              :value="level.value"
              :state="validation.state"
              :data-testid="`${level.value}-radio`"
              class="gl-mb-3"
            >
              <div class="gl-flex gl-items-center gl-gap-2">
                <gl-icon :size="16" :name="level.icon" />
                <span class="gl-font-semibold">
                  {{ level.label }}
                </span>
              </div>
              <template #help>{{ level.text }}</template>
            </gl-form-radio>
          </gl-form-radio-group>
          <gl-alert
            v-if="visibilityLevelAlertText"
            :dismissible="false"
            data-testid="agent-form-visibility-level-alert"
            class="gl-mt-3"
            variant="info"
          >
            {{ visibilityLevelAlertText }}
          </gl-alert>
        </template>
      </gl-form-fields>
      <ai-catalog-form-buttons :is-disabled="isLoading">
        <gl-button
          class="js-no-auto-disable"
          type="submit"
          variant="confirm"
          category="primary"
          data-testid="agent-form-submit-button"
          :loading="isLoading"
        >
          {{ submitButtonText }}
        </gl-button>
      </ai-catalog-form-buttons>
    </gl-form>
  </div>
</template>
