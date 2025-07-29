<script>
import { GlForm, GlAlert, GlButton } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { AVAILABILITY_OPTIONS } from '../constants';
import DuoAvailability from './duo_availability_form.vue';
import DuoExperimentBetaFeatures from './duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from './duo_core_features_form.vue';
import DuoPromptCache from './duo_prompt_cache_form.vue';

export default {
  name: 'AiCommonSettingsForm',
  components: {
    GlForm,
    GlAlert,
    GlButton,
    DuoAvailability,
    DuoExperimentBetaFeatures,
    DuoCoreFeaturesForm,
    DuoPromptCache,
  },
  i18n: {
    defaultOffWarning: s__(
      'AiPowered|When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
    ),
    confirmButtonText: __('Save changes'),
  },
  inject: ['onGeneralSettingsPage'],
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
    experimentFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
    duoCoreFeaturesEnabled: {
      type: Boolean,
      required: true,
      default: true,
    },
    promptCacheEnabled: {
      type: Boolean,
      required: true,
    },
    hasParentFormChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      availability: this.duoAvailability,
      experimentsEnabled: this.experimentFeaturesEnabled,
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
      cacheEnabled: this.promptCacheEnabled,
    };
  },
  computed: {
    hasAvailabilityChanged() {
      return this.availability !== this.duoAvailability;
    },
    hasExperimentCheckboxChanged() {
      return this.experimentsEnabled !== this.experimentFeaturesEnabled;
    },
    hasDuoCoreCheckboxChanged() {
      return this.duoCoreEnabled !== this.duoCoreFeaturesEnabled;
    },
    hasCacheCheckboxChanged() {
      return this.cacheEnabled !== this.promptCacheEnabled;
    },
    hasFormChanged() {
      return (
        this.hasAvailabilityChanged ||
        this.hasExperimentCheckboxChanged ||
        this.hasDuoCoreCheckboxChanged ||
        this.hasCacheCheckboxChanged ||
        this.hasParentFormChanged
      );
    },
    showWarning() {
      return this.hasAvailabilityChanged && this.warningAvailability;
    },
    warningAvailability() {
      return (
        this.availability === AVAILABILITY_OPTIONS.NEVER_ON ||
        this.availability === AVAILABILITY_OPTIONS.DEFAULT_OFF
      );
    },
    warningMessage() {
      const optsWithWarning = [AVAILABILITY_OPTIONS.DEFAULT_OFF, AVAILABILITY_OPTIONS.NEVER_ON];
      return optsWithWarning.includes(this.availability)
        ? this.$options.i18n.defaultOffWarning
        : '';
    },
    disableConfigCheckboxes() {
      return this.availability === AVAILABILITY_OPTIONS.NEVER_ON;
    },
  },
  methods: {
    submitForm() {
      this.$emit('submit');
    },
    onRadioChanged(value) {
      this.availability = value;
      this.$emit('radio-changed', value);
    },
    experimentCheckboxChanged(value) {
      this.experimentsEnabled = value;
      this.$emit('experiment-checkbox-changed', value);
    },
    duoCoreCheckboxChanged(value) {
      this.duoCoreEnabled = value;
      this.$emit('duo-core-checkbox-changed', value);
    },
    onCacheCheckboxChanged(value) {
      this.cacheEnabled = value;
      this.$emit('cache-checkbox-changed', value);
    },
  },
};
</script>

<template>
  <gl-form @submit.prevent="submitForm">
    <slot name="ai-common-settings-top"></slot>
    <duo-availability :duo-availability="availability" @change="onRadioChanged" />

    <duo-core-features-form
      v-if="!onGeneralSettingsPage"
      :duo-core-features-enabled="duoCoreEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="duoCoreCheckboxChanged"
    />

    <duo-experiment-beta-features
      :experiment-features-enabled="experimentsEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="experimentCheckboxChanged"
    />

    <duo-prompt-cache
      :prompt-cache-enabled="cacheEnabled"
      :disabled-checkbox="disableConfigCheckboxes"
      @change="onCacheCheckboxChanged"
    />

    <slot name="ai-common-settings-bottom"></slot>
    <gl-alert
      v-if="showWarning"
      :dismissible="false"
      variant="warning"
      data-testid="duo-settings-show-warning-alert"
    >
      {{ warningMessage }}
    </gl-alert>
    <gl-button class="gl-mt-6" type="submit" variant="confirm" :disabled="!hasFormChanged">
      {{ $options.i18n.confirmButtonText }}
    </gl-button>
  </gl-form>
</template>
