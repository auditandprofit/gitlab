<script>
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';

export default {
  name: 'BetaFeaturesAlert',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
  },
  props: {
    duoConfigurationSettingsPath: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <div class="gl-pb-4 gl-pt-2">
    <gl-alert variant="info" :dismissible="false">
      <gl-sprintf
        :message="
          s__(
            'AdminSelfHostedModels|More features are available in beta. You can %{linkStart}turn on AI-native beta features%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="duoConfigurationSettingsPath">
            {{ content }}
          </gl-link>
        </template></gl-sprintf
      ></gl-alert
    >
  </div>
</template>
