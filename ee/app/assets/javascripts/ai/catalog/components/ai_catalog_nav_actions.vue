<script>
import { GlButton } from '@gitlab/ui';
import { AI_CATALOG_AGENTS_NEW_ROUTE, AI_CATALOG_AGENTS_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogNavActions',
  components: {
    GlButton,
  },
  computed: {
    shouldDisplayButton() {
      return this.$route.path === AI_CATALOG_AGENTS_ROUTE;
    },
  },
  newAgentRoute: AI_CATALOG_AGENTS_NEW_ROUTE,
};
</script>

<template>
  <gl-button v-if="shouldDisplayButton" :to="{ name: $options.newAgentRoute }" variant="confirm">
    {{ s__('AICatalog|New agent') }}
  </gl-button>
</template>
