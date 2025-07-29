<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlFormGroup,
  GlFormInput,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __ } from '~/locale';
import { validateHexColor } from '~/lib/utils/color_utils';

export default {
  SUGGESTED_COLORS: gon.suggested_label_colors,
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlFormGroup,
    GlFormInput,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    categoryIcon: {
      type: String,
      required: true,
    },
    formData: {
      type: Object,
      required: true,
    },
    formErrors: {
      type: Object,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['save', 'cancel', 'update', 'validate'],
  data() {
    return {
      showDescriptionField:
        this.formData.description && this.formData.description.trim().length > 0,
      colorBeforeDropdownOpen: null,
    };
  },
  computed: {
    saveButtonText() {
      return this.isEditing ? __('Update') : __('Save');
    },
    saveButtonTestId() {
      return this.isEditing ? 'update-status' : 'save-status';
    },
  },
  mounted() {
    if (this.$refs.title) {
      this.$refs.title.$el.focus();
    }
  },
  methods: {
    getFormState(formError) {
      return formError ? false : null;
    },
    updateFormData(field, value) {
      this.$emit('update', {
        ...this.formData,
        [field]: value,
      });
    },
    handleSave() {
      this.$emit('save');
    },
    handleCancel() {
      this.$emit('cancel');
    },
    triggerValidation() {
      this.$emit('validate');
    },
    async handleToggleDescription() {
      this.showDescriptionField = !this.showDescriptionField;

      if (this.showDescriptionField) {
        await this.$nextTick();
        this.$refs.description.$el.focus();
      }
    },
    handleColorDropdownShow() {
      this.triggerValidation();
      this.colorBeforeDropdownOpen = this.formData.color;
      this.$refs.colorField?.$el?.focus();
    },
    handleColorDropdownHide() {
      if (!validateHexColor(this.formData.color)) {
        // If invalid, revert to the color it was when dropdown opened
        this.updateFormData('color', this.colorBeforeDropdownOpen);
      }
      this.$refs.title?.$el?.focus();
    },
  },
};
</script>

<template>
  <div class="gl-bg-subtle gl-p-4">
    <div class="gl-flex gl-flex-wrap gl-content-start gl-items-start gl-gap-4">
      <div class="gl-flex gl-grow gl-items-start gl-gap-4">
        <div class="gl-flex gl-items-end gl-gap-2">
          <gl-disclosure-dropdown
            data-testid="select-color"
            @shown="handleColorDropdownShow"
            @hidden="handleColorDropdownHide"
          >
            <template #toggle>
              <gl-button>
                <gl-icon :size="12" :name="categoryIcon" :style="{ color: formData.color }" />
                <gl-icon name="chevron-down" />
              </gl-button>
            </template>
            <template #header>
              <div class="gl-border-b gl-p-3 gl-font-bold">
                {{ __('Select a color') }}
              </div>
            </template>
            <template #default>
              <div class="gl-p-3">
                <div class="gl-mb-3 gl-flex gl-flex-wrap gl-gap-2">
                  <gl-button
                    v-for="(colorName, value) in $options.SUGGESTED_COLORS"
                    :key="value"
                    v-gl-tooltip
                    :title="colorName"
                    :aria-label="colorName"
                    class="gl-inline-block !gl-min-h-6 !gl-min-w-6 gl-rounded-base !gl-p-0 gl-no-underline"
                    :style="{ backgroundColor: value }"
                    @click.prevent="updateFormData('color', value)"
                  />
                </div>
                <gl-form-group
                  :label="s__('WorkItem|Color')"
                  label-sr-only
                  label-for="status-color"
                  class="gl-mb-0"
                  :invalid-feedback="formErrors.color"
                  :state="getFormState(formErrors.color)"
                >
                  <div class="gl-flex gl-items-center gl-gap-2">
                    <gl-form-input
                      :value="formData.color"
                      class="gl-h-8 gl-w-8"
                      type="color"
                      :state="getFormState(formErrors.color)"
                      data-testid="status-color-input"
                      @input="updateFormData('color', $event.trim())"
                    />
                    <gl-form-input
                      ref="colorField"
                      :value="formData.color"
                      :state="getFormState(formErrors.color)"
                      data-testid="status-color-input-text"
                      @input="updateFormData('color', $event.trim())"
                      @blur="triggerValidation"
                    />
                  </div>
                </gl-form-group>
              </div>
            </template>
          </gl-disclosure-dropdown>
        </div>
        <div
          class="gl-flex gl-grow gl-flex-wrap gl-items-start gl-gap-4 gl-gap-y-3"
          :class="{ 'gl-flex-col gl-items-stretch': showDescriptionField }"
        >
          <gl-form-group
            :label="s__('WorkItem|Title')"
            label-for="status-name"
            label-sr-only
            class="gl-mb-0 gl-shrink-0"
            :invalid-feedback="formErrors.name"
            :state="getFormState(formErrors.name)"
          >
            <gl-form-input
              id="status-name"
              ref="title"
              :placeholder="__('Name')"
              :value="formData.name"
              :maxlength="32"
              width="sm"
              :state="getFormState(formErrors.name)"
              autofocus
              autocomplete="off"
              data-testid="status-name-input"
              class="gl-flex-grow-1"
              @input="updateFormData('name', $event)"
              @keyup.enter="handleSave"
            />
          </gl-form-group>

          <gl-button
            v-if="!showDescriptionField"
            class="gl-shrink-0"
            category="tertiary"
            data-testid="add-description-button"
            @click="handleToggleDescription"
          >
            {{ s__('WorkItem|Add description') }}
          </gl-button>
          <div v-if="showDescriptionField">
            <gl-form-group
              :label="s__('WorkItem|Description')"
              label-for="status-description"
              class="gl-mb-0"
            >
              <gl-form-input
                id="status-description"
                ref="description"
                :value="formData.description"
                maxlength="128"
                data-testid="status-description-input"
                @input="updateFormData('description', $event)"
              />
            </gl-form-group>
          </div>
        </div>
      </div>
      <div class="gl-flex gl-gap-2">
        <gl-button variant="confirm" :data-testid="saveButtonTestId" @click="handleSave">
          {{ saveButtonText }}
        </gl-button>
        <gl-button data-testid="cancel-status" @click="handleCancel">
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
