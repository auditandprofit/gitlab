<script>
import { GlButton, GlFormCheckbox, GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import CloudUserIllustrationPath from '@gitlab/svgs/dist/illustrations/cloud-user-sm.svg';

import ClearProjectSettingsModal from './clear_project_settings_modal.vue';
import ProviderSettingsPreview from './provider_settings_preview.vue';
import ProviderSettingsForm from './provider_settings_form.vue';
import { projectSettingsValidator } from './utils';

export default {
  name: 'SelfManagedProviderCard',
  components: {
    ClearProjectSettingsModal,
    GlButton,
    GlFormCheckbox,
    GlLink,
    GlModal,
    GlSprintf,
    ProviderSettingsForm,
    ProviderSettingsPreview,
  },
  inject: {
    isInstanceConfiguredWithSelfManagedAnalyticsProvider: {
      default: false,
    },
    defaultUseInstanceConfiguration: {
      default: false,
    },
  },
  props: {
    projectSettings: {
      type: Object,
      required: true,
      validator: projectSettingsValidator,
    },
  },
  data() {
    return {
      useInstanceConfiguration: this.defaultUseInstanceConfiguration,
      clearSettingsModalIsVisible: false,
      editSettingsModalIsVisible: false,
    };
  },
  computed: {
    hasAllProjectLevelSettings() {
      return Object.values(this.projectSettings).every(Boolean);
    },
    hasEmptyProjectLevelSettings() {
      return !Object.values(this.projectSettings).some(Boolean);
    },
    requiresProjectSettingsClearing() {
      return this.useInstanceConfiguration && !this.hasEmptyProjectLevelSettings;
    },
    requiresProjectSettingsEditing() {
      return !this.useInstanceConfiguration && !this.hasAllProjectLevelSettings;
    },
  },
  methods: {
    async onSelected() {
      if (this.requiresProjectSettingsClearing) {
        this.clearSettingsModalIsVisible = true;
        return;
      }

      if (this.requiresProjectSettingsEditing) {
        this.editSettingsModalIsVisible = true;
        return;
      }

      this.$emit('confirm', CloudUserIllustrationPath);
    },
    onSettingsSaved() {
      this.editSettingsModalIsVisible = false;
      this.onSelected();
    },
  },
  CloudUserIllustrationPath,
};
</script>
<template>
  <div class="gl-flex gl-w-full gl-gap-6 gl-rounded-base gl-border-solid gl-border-default gl-p-6">
    <div class="gl-hidden gl-shrink-0 md:gl-block">
      <img class="gl-dark-invert-keep-hue" :src="$options.CloudUserIllustrationPath" :alt="''" />
    </div>
    <div class="gl-flex gl-w-full gl-grow gl-flex-col">
      <h3 class="gl-mt-0">
        {{ s__('ProductAnalytics|Self-managed provider') }}
      </h3>
      <p class="gl-mb-6">
        {{
          s__(
            'ProductAnalytics|Manage your own analytics provider to process, store, and query analytics data.',
          )
        }}
      </p>
      <gl-form-checkbox
        v-if="isInstanceConfiguredWithSelfManagedAnalyticsProvider"
        v-model="useInstanceConfiguration"
        class="gl-mb-6"
        data-testid="use-instance-configuration-checkbox"
        >{{ s__('ProductAnalytics|Use instance provider settings') }}
        <template #help>{{
          s__(
            'ProductAnalytics|Uncheck if you would like to configure a different provider for this project.',
          )
        }}</template>
      </gl-form-checkbox>
      <p v-if="useInstanceConfiguration">
        {{
          s__(
            'ProductAnalytics|Your instance will be created on the provider configured in your instance settings.',
          )
        }}
      </p>
      <template v-else-if="hasAllProjectLevelSettings">
        <p>{{ s__('ProductAnalytics|Your instance will be created on this provider:') }}</p>
        <provider-settings-preview
          :configurator-connection-string="
            projectSettings.productAnalyticsConfiguratorConnectionString
          "
          :collector-host="projectSettings.productAnalyticsDataCollectorHost"
          :cube-api-base-url="projectSettings.cubeApiBaseUrl"
          :cube-api-key="projectSettings.cubeApiKey"
        />
      </template>
      <template v-else>
        <h4 class="gl-mt-0 gl-text-lg">{{ s__('ProductAnalytics|For this option, you need:') }}</h4>
        <ul class="gl-mb-6">
          <li>
            <gl-sprintf
              :message="
                s__(
                  'ProductAnalytics|A deployed instance of the %{linkStart}helm-charts%{linkEnd} project.',
                )
              "
            >
              <template #link="{ content }">
                <gl-link
                  href="https://gitlab.com/gitlab-org/analytics-section/product-analytics/helm-charts"
                  target="_blank"
                  >{{ content }}</gl-link
                >
              </template>
            </gl-sprintf>
          </li>
          <li>{{ s__('ProductAnalytics|Valid project settings.') }}</li>
        </ul>
      </template>

      <gl-button
        category="primary"
        variant="confirm"
        class="gl-mt-auto gl-self-start"
        data-testid="connect-your-own-provider-btn"
        @click="onSelected"
        >{{ s__('ProductAnalytics|Connect your own provider') }}</gl-button
      >
    </div>
    <clear-project-settings-modal
      :visible="clearSettingsModalIsVisible"
      @hide="clearSettingsModalIsVisible = false"
      @cleared="onSelected"
    >
      {{
        s__(
          `ProductAnalytics|This project has analytics provider settings configured. If you continue, the settings for projects will be reset so that provider settings for the instance can be used.`,
        )
      }}
    </clear-project-settings-modal>
    <gl-modal
      :visible="editSettingsModalIsVisible"
      data-testid="edit-project-level-settings-modal"
      modal-id="edit-project-level-settings-modal"
      :title="s__('ProductAnalytics|Edit project provider settings')"
      hide-footer
      @change="(visible) => (editSettingsModalIsVisible = visible)"
    >
      <provider-settings-form
        :project-settings="projectSettings"
        @canceled="editSettingsModalIsVisible = false"
        @saved="onSettingsSaved"
      />
    </gl-modal>
  </div>
</template>
