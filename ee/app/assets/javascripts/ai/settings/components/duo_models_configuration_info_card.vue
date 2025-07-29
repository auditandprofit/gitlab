<script>
import { GlButton, GlCard } from '@gitlab/ui';

export default {
  name: 'DuoModelsConfigurationInfoCard',
  components: {
    GlButton,
    GlCard,
  },
  props: {
    duoModelsConfigurationProps: {
      type: Object,
      required: true,
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-bg-transparent gl-border-none gl-pb-0"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
  >
    <template #header>
      <h2 class="gl-m-0 gl-text-lg">
        {{ duoModelsConfigurationProps.header }}
      </h2>
      <p
        data-testid="model-configuration-card-secondary-header"
        class="gl-m-0 gl-text-size-h-display gl-font-bold"
      >
        {{ s__('AiPowered|Configure AI features') }}
      </p>
    </template>
    <template #default>
      <p data-testid="model-configuration-card-description" class="gl-mb-0 gl-pb-0 gl-text-subtle">
        {{ duoModelsConfigurationProps.description }}
      </p>
    </template>
    <template #footer>
      <div>
        <gl-button :to="duoModelsConfigurationProps.path" category="primary" variant="confirm">
          {{ duoModelsConfigurationProps.buttonText }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
