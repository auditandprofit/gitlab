<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCommonSettingsForm from './ai_common_settings_form.vue';

export default {
  name: 'AiCommonSettings',
  components: {
    GlLink,
    GlSprintf,
    SettingsBlock,
    AiCommonSettingsForm,
    PageHeading,
  },
  i18n: {
    confirmButtonText: __('Save changes'),
    settingsBlockTitle: __('GitLab Duo features'),
    settingsBlockDescription: s__(
      'AiPowered|Configure AI-native GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
    ),
    configurationPageTitle: s__('AiPowered|Configuration'),
  },
  inject: [
    'duoAvailability',
    'experimentFeaturesEnabled',
    'duoCoreFeaturesEnabled',
    'onGeneralSettingsPage',
    'promptCacheEnabled',
  ],
  props: {
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
  methods: {
    submitForm() {
      this.$emit('submit', {
        duoAvailability: this.availability,
        experimentFeaturesEnabled: this.experimentsEnabled,
        duoCoreFeaturesEnabled: this.duoCoreEnabled,
        promptCacheEnabled: this.cacheEnabled,
      });
    },
    onRadioChanged(value) {
      this.availability = value;
    },
    experimentCheckboxChanged(value) {
      this.experimentsEnabled = value;
    },
    duoCoreCheckboxChanged(value) {
      this.duoCoreEnabled = value;
    },
    onCacheCheckboxChanged(value) {
      this.cacheEnabled = value;
    },
  },
  aiFeaturesHelpPath: helpPagePath('user/ai_features'),
};
</script>
<template>
  <div>
    <template v-if="onGeneralSettingsPage">
      <settings-block class="gl-mb-5 !gl-pt-5" :title="$options.i18n.settingsBlockTitle">
        <template #description>
          <gl-sprintf
            data-testid="general-settings-subtitle"
            :message="
              s__(
                'AiPowered|Configure AI-native GitLab Duo features. %{linkStart}Which features?%{linkEnd}',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.aiFeaturesHelpPath">{{ content }} </gl-link>
            </template>
          </gl-sprintf>
        </template>
        <template #default>
          <ai-common-settings-form
            :duo-availability="duoAvailability"
            :experiment-features-enabled="experimentFeaturesEnabled"
            :duo-core-features-enabled="duoCoreFeaturesEnabled"
            :prompt-cache-enabled="promptCacheEnabled"
            :has-parent-form-changed="hasParentFormChanged"
            @submit="submitForm"
            @radio-changed="onRadioChanged"
            @experiment-checkbox-changed="experimentCheckboxChanged"
            @duo-core-checkbox-changed="duoCoreCheckboxChanged"
            @cache-checkbox-changed="onCacheCheckboxChanged"
          >
            <template #ai-common-settings-top>
              <slot name="ai-common-settings-top"></slot>
            </template>
          </ai-common-settings-form>
        </template>
      </settings-block>
    </template>
    <template v-else>
      <page-heading :heading="$options.i18n.configurationPageTitle">
        <template #description>
          <span data-testid="configuration-page-subtitle">
            <gl-sprintf :message="$options.i18n.settingsBlockDescription">
              <template #link="{ content }">
                <gl-link :href="$options.aiFeaturesHelpPath">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </span>
        </template>
      </page-heading>
      <ai-common-settings-form
        :duo-availability="duoAvailability"
        :experiment-features-enabled="experimentFeaturesEnabled"
        :duo-core-features-enabled="duoCoreFeaturesEnabled"
        :prompt-cache-enabled="promptCacheEnabled"
        :has-parent-form-changed="hasParentFormChanged"
        @submit="submitForm"
        @radio-changed="onRadioChanged"
        @experiment-checkbox-changed="experimentCheckboxChanged"
        @duo-core-checkbox-changed="duoCoreCheckboxChanged"
        @cache-checkbox-changed="onCacheCheckboxChanged"
      >
        <template #ai-common-settings-top>
          <slot name="ai-common-settings-top"></slot>
        </template>
        <template #ai-common-settings-bottom>
          <slot name="ai-common-settings-bottom"></slot>
        </template>
      </ai-common-settings-form>
    </template>
  </div>
</template>
