<script>
import { GlBanner } from '@gitlab/ui';
import { __ } from '~/locale';
import SecurityTrainingPromo from 'ee/vue_shared/security_reports/components/security_training_promo.vue';
import { i18n } from '~/security_configuration/constants';

export default {
  components: {
    GlBanner,
    SecurityTrainingPromo,
  },
  inject: ['securityConfigurationPath'],
  i18n: {
    title: __('Reduce risk and triage fewer vulnerabilities with security training'),
    content: i18n.securityTrainingDescription,
  },
};
</script>

<template>
  <security-training-promo :security-configuration-path="securityConfigurationPath">
    <template #default="{ buttonLink, buttonText, dismiss, trackCTAClick }">
      <gl-banner
        :title="$options.i18n.title"
        :button-text="buttonText"
        :button-link="buttonLink"
        variant="introduction"
        @primary="trackCTAClick"
        @close="dismiss"
      >
        <p>{{ $options.i18n.content }}</p>
      </gl-banner>
    </template>
  </security-training-promo>
</template>
