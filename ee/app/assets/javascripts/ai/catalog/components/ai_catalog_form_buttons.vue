<script>
import { GlButton } from '@gitlab/ui';
import { AI_CATALOG_AGENTS_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogFormButtons',
  components: {
    GlButton,
  },
  props: {
    isDisabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  indexRoute: AI_CATALOG_AGENTS_ROUTE,
};
</script>

<template>
  <div class="gl-flex gl-gap-3">
    <slot></slot>
    <gl-button
      :disabled="isDisabled"
      :to="{ name: $options.indexRoute }"
      type="button"
      category="secondary"
    >
      {{ __('Cancel') }}
    </gl-button>
  </div>
</template>
