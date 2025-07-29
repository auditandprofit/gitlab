<script>
import { updateGroupSettings } from 'ee/api/groups_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __ } from '~/locale';
import AiCommonSettings from '../components/ai_common_settings.vue';
import DuoWorkflowSettingsForm from '../components/duo_workflow_settings_form.vue';

const EarlyAccessProgramBanner = () => import('../components/early_access_program_banner.vue');

export default {
  name: 'AiGroupSettings',
  components: {
    AiCommonSettings,
    EarlyAccessProgramBanner,
    DuoWorkflowSettingsForm,
  },
  i18n: {
    successMessage: __('Group was successfully updated.'),
    errorMessage: __(
      'An error occurred while retrieving your settings. Reload the page to try again.',
    ),
  },
  inject: [
    'showEarlyAccessBanner',
    'onGeneralSettingsPage',
    'duoWorkflowAvailable',
    'duoWorkflowMcpEnabled',
  ],
  props: {
    redirectPath: {
      type: String,
      required: false,
      default: '',
    },
    updateId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      duoWorkflowMcp: this.duoWorkflowMcpEnabled,
    };
  },
  computed: {
    hasFormChanged() {
      return this.duoWorkflowMcpEnabled !== this.duoWorkflowMcp;
    },
  },
  methods: {
    async updateSettings({
      duoAvailability,
      experimentFeaturesEnabled,
      duoCoreFeaturesEnabled,
      promptCacheEnabled,
    }) {
      try {
        const input = {
          duo_availability: duoAvailability,
          experiment_features_enabled: experimentFeaturesEnabled,
          model_prompt_cache_enabled: promptCacheEnabled,
          ai_settings_attributes: {
            duo_workflow_mcp_enabled: this.duoWorkflowMcp,
          },
        };

        if (!this.onGeneralSettingsPage) {
          input.duo_core_features_enabled = duoCoreFeaturesEnabled;
        }

        await updateGroupSettings(this.updateId, input);

        visitUrlWithAlerts(this.redirectPath, [
          {
            id: 'organization-group-successfully-updated',
            message: this.$options.i18n.successMessage,
            variant: VARIANT_INFO,
          },
        ]);
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
      }
    },
    onDuoWorkflowFormChanged(value) {
      this.duoWorkflowMcp = value;
    },
  },
};
</script>
<template>
  <ai-common-settings :has-parent-form-changed="hasFormChanged" @submit="updateSettings">
    <template #ai-common-settings-top>
      <early-access-program-banner v-if="showEarlyAccessBanner" />
    </template>

    <template #ai-common-settings-bottom>
      <duo-workflow-settings-form
        v-if="duoWorkflowAvailable"
        :is-mcp-enabled="duoWorkflowMcp"
        @change="onDuoWorkflowFormChanged"
      />
    </template>
  </ai-common-settings>
</template>
