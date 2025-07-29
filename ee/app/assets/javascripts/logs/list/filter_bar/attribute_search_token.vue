<script>
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { s__ } from '~/locale';

export default {
  components: {
    BaseToken,
  },
  i18n: {
    placeholderName: s__('ObservabilityLogs|name'),
    placeholderValue: s__('ObservabilityLogs|value'),
  },
  props: {
    active: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  computed: {
    inputAttributes() {
      return {
        placeholder: `${this.$options.i18n.placeholderName}=${this.$options.i18n.placeholderValue}`,
      };
    },
    tokenConfig() {
      return {
        ...this.config,
        suggestionsDisabled: true,
      };
    },
  },
};
</script>

<template>
  <base-token
    v-bind="$attrs"
    :active="active"
    :config="tokenConfig"
    :value="value"
    :data-segment-input-attributes="inputAttributes"
    v-on="$listeners"
  />
</template>
