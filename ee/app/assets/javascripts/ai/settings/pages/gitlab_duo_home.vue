<script>
import { __, s__ } from '~/locale';
import { DUO_CORE, DUO_PRO, DUO_ENTERPRISE } from 'ee/constants/duo';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoCoreUpgradeCard from 'ee/ai/settings/components/duo_core_upgrade_card.vue';
import DuoSeatUtilizationInfoCard from '../components/duo_seat_utilization_info_card.vue';
import DuoConfigurationSettingsInfoCard from '../components/duo_configuration_settings_info_card.vue';
import DuoModelsConfigurationInfoCard from '../components/duo_models_configuration_info_card.vue';
import DuoWorkflowSettings from '../components/duo_workflow_settings.vue';

export default {
  name: 'GitlabDuoHome',
  components: {
    CodeSuggestionsUsage,
    HealthCheckList,
    DuoConfigurationSettingsInfoCard,
    DuoCoreUpgradeCard,
    DuoSeatUtilizationInfoCard,
    DuoModelsConfigurationInfoCard,
    DuoWorkflowSettings,
  },
  inject: {
    canManageSelfHostedModels: { default: false },
    duoSelfHostedPath: { default: '' },
    isSaaS: {},
    modelSwitchingEnabled: { default: false },
    modelSwitchingPath: { default: '' },
    showDuoWorkflowSettings: { default: false },
  },
  i18n: {
    gitlabDuoHomeTitle: __('GitLab Duo'),
    gitlabDuoHomeSubtitle: s__(
      'AiPowered|Monitor, manage, and customize AI-powered features to ensure efficient utilization and alignment.',
    ),
  },
  computed: {
    isModelSwitchingEnabled() {
      return this.isSaaS && this.modelSwitchingEnabled;
    },
    isSelfHostedModelsEnabled() {
      return !this.isSaaS && this.canManageSelfHostedModels;
    },
    duoModelsConfigurationProps() {
      if (this.isModelSwitchingEnabled) {
        return {
          header: s__('AiPowered|Model Selection'),
          description: s__('AiPowered|Assign models to AI-native features.'),
          buttonText: s__('AiPowered|Configure features'),
          path: this.modelSwitchingPath,
        };
      }

      if (this.isSelfHostedModelsEnabled) {
        return {
          header: s__('AiPowered|GitLab Duo Self-Hosted'),
          description: s__('AiPowered|Assign self-hosted models to specific AI-native features.'),
          buttonText: s__('AiPowered|Configure GitLab Duo Self-Hosted'),
          path: this.duoSelfHostedPath,
        };
      }

      return {};
    },
  },
  methods: {
    shouldShowDuoCoreUpgradeCard(activeDuoTier) {
      return activeDuoTier === DUO_CORE;
    },
    shouldShowSeatUtilizationInfoCard(activeDuoTier) {
      return activeDuoTier === DUO_PRO || activeDuoTier === DUO_ENTERPRISE;
    },
  },
};
</script>

<template>
  <div>
    <code-suggestions-usage
      :title="$options.i18n.gitlabDuoHomeTitle"
      :subtitle="$options.i18n.gitlabDuoHomeSubtitle"
      :force-hide-title="false"
      v-bind="$attrs"
    >
      <template #health-check>
        <health-check-list v-if="!isSaaS" />
      </template>
      <template #duo-card="{ totalValue, usageValue, activeDuoTier, addOnPurchases }">
        <section class="gl-grid gl-gap-5 gl-pb-5 md:gl-grid-cols-2">
          <duo-core-upgrade-card v-if="shouldShowDuoCoreUpgradeCard(activeDuoTier)" />
          <duo-seat-utilization-info-card
            v-if="shouldShowSeatUtilizationInfoCard(activeDuoTier)"
            :total-value="totalValue"
            :usage-value="usageValue"
            :active-duo-tier="activeDuoTier"
            :add-on-purchases="addOnPurchases"
          />
          <duo-configuration-settings-info-card :active-duo-tier="activeDuoTier" />
        </section>
        <duo-models-configuration-info-card
          v-if="isModelSwitchingEnabled || isSelfHostedModelsEnabled"
          :duo-models-configuration-props="duoModelsConfigurationProps"
        />
      </template>
    </code-suggestions-usage>
    <duo-workflow-settings v-if="showDuoWorkflowSettings" />
  </div>
</template>
