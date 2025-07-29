<script>
import {
  GlAlert,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlLink,
  GlSprintf,
  GlButton,
  GlPopover,
  GlAccordion,
  GlAccordionItem,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import ColorPicker from '~/vue_shared/components/color_picker/color_picker.vue';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS as DEBOUNCE_DELAY } from '~/lib/utils/constants';
import { validateHexColor } from '~/lib/utils/color_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  validatePipelineConfirmationFormat,
  fetchPipelineConfigurationFileExists,
} from 'ee/groups/settings/compliance_frameworks/utils';
import { maxNameLength, i18n } from '../constants';
import EditSection from './edit_section.vue';

const RESERVED_NAMES = ['default', __('default')];

export default {
  components: {
    ColorPicker,
    EditSection,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlLink,
    GlSprintf,
    GlPopover,
    GlAlert,
    GlButton,
    GlFormTextarea,
    GlAccordion,
    GlAccordionItem,
  },
  inject: [
    'migratePipelineToPolicyPath',
    'pipelineConfigurationFullPathEnabled',
    'pipelineConfigurationEnabled',
    'pipelineExecutionPolicyPath',
  ],
  props: {
    value: {
      type: Object,
      required: true,
    },
    isExpanded: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasMigratedPipeline: {
      type: Boolean,
      required: false,
      default: false,
    },
    showValidation: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  data() {
    return {
      formData: JSON.parse(JSON.stringify(this.value)),
      maintenanceModeDismissed: false,
      pipelineConfigurationFileExists: true,
    };
  },

  computed: {
    isCreatingNewPolicy() {
      return !this.formData.pipelineConfigurationFullPath || !this.formData.id;
    },

    dynamicMigratePipelineToPolicyPath() {
      if (this.isCreatingNewPolicy) {
        return this.pipelineExecutionPolicyPath;
      }

      const url = new URL(this.pipelineExecutionPolicyPath, document.location.href);
      url.searchParams.set('path', this.formData.pipelineConfigurationFullPath);
      url.searchParams.set('compliance_framework_name', this.formData.name);
      url.searchParams.set('compliance_framework_id', getIdFromGraphQLId(this.formData.id));

      return url.toString();
    },
    deprecationWarningButtonText() {
      if (this.isCreatingNewPolicy) {
        return this.$options.i18n.deprecationWarning.migratePipelineToPolicyEmpty;
      }

      // migrate pipeline to policy
      return this.$options.i18n.deprecationWarning.migratePipelineToPolicy;
    },
    pipelineConfigurationFeedbackMessage() {
      if (!this.isValidPipelineConfigurationFormat) {
        return this.$options.i18n.pipelineConfigurationInputInvalidFormat;
      }

      return this.$options.i18n.pipelineConfigurationInputUnknownFile;
    },

    nameFeedbackMessage() {
      if (!this.formData.name || this.formData.name.length > maxNameLength) {
        return this.$options.i18n.titleInputInvalid;
      }
      if (RESERVED_NAMES.includes(this.formData.name.toLowerCase())) {
        return this.$options.i18n.nameInputReserved(this.formData.name);
      }
      return '';
    },

    compliancePipelineConfigurationHelpPath() {
      return helpPagePath('user/compliance/compliance_pipelines', {
        anchor: 'example-configuration',
      });
    },

    isValidColor() {
      return Boolean(this.formData.color) && validateHexColor(this.formData.color);
    },

    isValidName() {
      return Boolean(this.formData.name) && this.nameFeedbackMessage === '';
    },

    isValidDescription() {
      return Boolean(this.formData.description);
    },

    isValidPipelineConfiguration() {
      if (!this.formData.pipelineConfigurationFullPath) {
        return null;
      }

      return this.isValidPipelineConfigurationFormat && this.pipelineConfigurationFileExists;
    },

    isValidPipelineConfigurationFormat() {
      return validatePipelineConfirmationFormat(this.formData.pipelineConfigurationFullPath);
    },

    isValid() {
      return (
        this.isValidName &&
        this.isValidDescription &&
        this.isValidColor &&
        this.isValidPipelineConfiguration !== false
      );
    },
    showMaintenanceModeAlert() {
      return !this.maintenanceModeDismissed;
    },
    showPostMigrationAlert() {
      return !this.isCreatingNewPolicy && this.hasMigratedPipeline;
    },
    expandPipelineConfig() {
      return Boolean(this.formData.pipelineConfigurationFullPath);
    },

    isNameFeedbackVisible() {
      return this.getValidationState(this.isValidName);
    },

    isDescriptionFeedbackVisible() {
      return this.getValidationState(this.isValidDescription);
    },

    isPipelineConfigurationFeedbackVisible() {
      return this.getValidationState(this.isValidPipelineConfiguration);
    },

    isColorFeedbackVisible() {
      return this.getValidationState(this.isValidColor);
    },
  },

  watch: {
    formData: {
      handler(newValue) {
        this.$emit('input', newValue);
      },
      deep: true,
    },
    'formData.pipelineConfigurationFullPath': {
      handler(path) {
        if (path) {
          this.validatePipelineInput(path);
        }
      },
    },
  },

  methods: {
    async validatePipelineConfigurationPath(path) {
      this.pipelineConfigurationFileExists = await fetchPipelineConfigurationFileExists(path);
    },

    validatePipelineInput: debounce(function debounceValidation(path) {
      this.validatePipelineConfigurationPath(path);
    }, DEBOUNCE_DELAY),

    handleOnDismissMaintenanceMode() {
      this.maintenanceModeDismissed = true;
    },

    getValidationState(state) {
      return this.showValidation ? state : true;
    },
  },

  i18n,
  disabledPipelineConfigurationInputPopoverTarget:
    'disabled-pipeline-configuration-input-popover-target',
};
</script>
<template>
  <edit-section
    :title="$options.i18n.basicInformation"
    :description="$options.i18n.basicInformationDescription"
    :initially-expanded="isExpanded"
    is-required
    :is-completed="isValid"
  >
    <div class="gl-px-4">
      <gl-form-group
        :label="$options.i18n.titleInputLabel"
        label-for="name-input"
        :state="isNameFeedbackVisible"
        :invalid-feedback="nameFeedbackMessage"
        data-testid="name-input-group"
      >
        <gl-form-input
          id="name-input"
          v-model="formData.name"
          name="name"
          :state="isNameFeedbackVisible"
          data-testid="name-input"
        />
      </gl-form-group>

      <gl-form-group
        :label="$options.i18n.descriptionInputLabel"
        label-for="description-input"
        :invalid-feedback="$options.i18n.descriptionInputInvalid"
        :state="isDescriptionFeedbackVisible"
        data-testid="description-input-group"
      >
        <gl-form-textarea
          id="description-input"
          v-model="formData.description"
          name="description"
          :state="isDescriptionFeedbackVisible"
          data-testid="description-input"
          :no-resize="false"
          :rows="5"
        />
      </gl-form-group>
      <color-picker
        v-model="formData.color"
        :label="$options.i18n.colorInputLabel"
        :state="isColorFeedbackVisible"
      />
      <gl-accordion :auto-collapse="false" :header-level="1">
        <gl-accordion-item
          :title="$options.i18n.pipelineConfigurationInputLabel"
          :header-level="1"
          :visible="expandPipelineConfig"
        >
          <gl-form-group
            v-if="pipelineConfigurationFullPathEnabled && pipelineConfigurationEnabled"
            label-for="pipeline-configuration-input"
            :invalid-feedback="pipelineConfigurationFeedbackMessage"
            :state="isPipelineConfigurationFeedbackVisible"
            data-testid="pipeline-configuration-input-group"
          >
            <template #description>
              <gl-sprintf :message="$options.i18n.pipelineConfigurationInputDescription">
                <template #code="{ content }">
                  <code>{{ content }}</code>
                </template>

                <template #link="{ content }">
                  <gl-link :href="compliancePipelineConfigurationHelpPath" target="_blank">{{
                    content
                  }}</gl-link>
                </template>
              </gl-sprintf>
            </template>

            <gl-alert
              v-if="showMaintenanceModeAlert"
              variant="warning"
              class="gl-my-3"
              data-testid="maintenance-mode-alert"
              :dismissible="true"
              :title="$options.i18n.deprecationWarning.title"
              @dismiss="handleOnDismissMaintenanceMode"
            >
              <template v-if="showPostMigrationAlert">
                <p
                  v-for="(message, index) in $options.i18n.deprecationWarning.postMigrationMessages"
                  :key="index"
                >
                  {{ message }}
                </p>
              </template>
              <template v-else>
                <p>
                  <gl-sprintf :message="$options.i18n.deprecationWarning.message">
                    <template #link="{ content }">
                      <gl-link :href="pipelineExecutionPolicyPath" target="_blank">{{
                        content
                      }}</gl-link>
                    </template>
                  </gl-sprintf>
                </p>

                <gl-sprintf :message="$options.i18n.deprecationWarning.details">
                  <template #link="{ content }">
                    <gl-link :href="migratePipelineToPolicyPath" target="_blank">{{
                      content
                    }}</gl-link>
                  </template>
                </gl-sprintf>
              </template>
              <template v-if="!showPostMigrationAlert" #actions>
                <gl-button
                  category="primary"
                  variant="confirm"
                  data-testid="migrate-action-button"
                  :href="dynamicMigratePipelineToPolicyPath"
                  target="_blank"
                >
                  {{ deprecationWarningButtonText }}
                </gl-button>

                <gl-button class="gl-ml-5" @click="handleOnDismissMaintenanceMode">
                  {{ $options.i18n.deprecationWarning.dismiss }}
                </gl-button>
              </template>
            </gl-alert>

            <gl-form-input
              id="pipeline-configuration-input"
              v-model="formData.pipelineConfigurationFullPath"
              name="pipeline_configuration_full_path"
              :state="isPipelineConfigurationFeedbackVisible"
              data-testid="pipeline-configuration-input"
            />
          </gl-form-group>
        </gl-accordion-item>
      </gl-accordion>
      <template v-if="!pipelineConfigurationEnabled">
        <gl-form-group
          id="disabled-pipeline-configuration-input-group"
          :label="$options.i18n.pipelineConfigurationInputLabel"
          label-for="disabled-pipeline-configuration-input"
          data-testid="disabled-pipeline-configuration-input-group"
        >
          <div :id="$options.disabledPipelineConfigurationInputPopoverTarget" tabindex="0">
            <gl-form-input
              id="disabled-pipeline-configuration-input"
              disabled
              data-testid="disabled-pipeline-configuration-input"
            />
          </div>
        </gl-form-group>
        <gl-popover
          :title="$options.i18n.pipelineConfigurationInputDisabledPopoverTitle"
          show-close-button
          :target="$options.disabledPipelineConfigurationInputPopoverTarget"
          data-testid="disabled-pipeline-configuration-input-popover"
        >
          <p class="gl-mb-0">
            <gl-sprintf :message="$options.i18n.pipelineConfigurationInputDisabledPopoverContent">
              <template #link="{ content }">
                <gl-link
                  :href="$options.i18n.pipelineConfigurationInputDisabledPopoverLink"
                  target="_blank"
                  class="gl-text-sm"
                >
                  {{ content }}</gl-link
                >
              </template>
            </gl-sprintf>
          </p>
        </gl-popover>
      </template>
      <gl-form-checkbox v-model="formData.default" name="default" class="gl-mt-5">
        <span class="gl-font-bold">{{ $options.i18n.setAsDefault }}</span>
        <template #help>
          <div>
            {{ $options.i18n.setAsDefaultDetails }}
            {{ $options.i18n.setAsDefaultOnlyOne }}
          </div>
        </template>
      </gl-form-checkbox>
    </div>
  </edit-section>
</template>
