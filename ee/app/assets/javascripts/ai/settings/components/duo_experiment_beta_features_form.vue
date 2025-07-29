<script>
import { GlSprintf, GlFormCheckbox, GlPopover } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'DuoExperimentBetaFeaturesForm',
  i18n: {
    sectionTitle: __('Feature preview'),
    checkboxLabel: s__('AiPowered|Turn on experiment and beta GitLab Duo features'),
    checkboxHelpText: s__(
      'AiPowered|By turning on these features, you accept the %{linkStart}GitLab Testing Agreement%{linkEnd}.',
    ),
    popoverTitle: s__('AiPowered|Setting unavailable'),
    popoverContent: s__(
      'AiPowered|When GitLab Duo is not available, experiment and beta features cannot be turned on.',
    ),
  },
  components: {
    GlSprintf,
    GlFormCheckbox,
    GlPopover,
    PromoPageLink,
  },
  inject: ['areExperimentSettingsAllowed'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    experimentFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      experimentsEnabled: this.experimentFeaturesEnabled,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.experimentsEnabled);
    },
  },
  experimentBetaHelpPath: helpPagePath('policy/development_stages_support'),
  testingAgreementPath: `/handbook/legal/testing-agreement/`,
};
</script>
<template>
  <div v-if="areExperimentSettingsAllowed">
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-checkbox
      v-model="experimentsEnabled"
      data-testid="use-experimental-features-checkbox"
      :disabled="disabledCheckbox"
      @change="checkboxChanged"
    >
      <span id="duo-experiment-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
      <template #help>
        <gl-sprintf :message="$options.i18n.checkboxHelpText">
          <template #link="{ content }">
            <promo-page-link :path="$options.testingAgreementPath" target="_blank">{{
              content
            }}</promo-page-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-form-checkbox>
    <gl-popover v-if="disabledCheckbox" target="duo-experiment-checkbox-label">
      <template #title>{{ $options.i18n.popoverTitle }}</template>
      <span data-testid="duo-experiment-popover">
        {{ $options.i18n.popoverContent }}
      </span>
    </gl-popover>
  </div>
</template>
