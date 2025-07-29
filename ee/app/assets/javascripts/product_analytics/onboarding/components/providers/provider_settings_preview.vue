<script>
import { s__ } from '~/locale';

const MASK_STRING = '****************';

export default {
  name: 'ProviderSettingsPreview',
  props: {
    configuratorConnectionString: {
      type: String,
      required: false,
      default: null,
    },
    collectorHost: {
      type: String,
      required: false,
      default: null,
    },
    cubeApiBaseUrl: {
      type: String,
      required: false,
      default: null,
    },
    cubeApiKey: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    showSettings() {
      return this.settings.length > 0;
    },
    settings() {
      return [
        {
          label: s__('ProductAnalytics|Snowplow configurator connection string'),
          value: this.maskValue(this.configuratorConnectionString),
        },
        {
          label: s__('ProductAnalytics|Collector host'),
          value: this.collectorHost,
        },
        {
          label: s__('ProductAnalytics|Cube API URL'),
          value: this.cubeApiBaseUrl,
        },
        {
          label: s__('ProductAnalytics|Cube API key'),
          value: this.maskValue(this.cubeApiKey),
        },
      ].filter(({ value }) => Boolean(value));
    },
  },
  methods: {
    maskValue(value) {
      return value ? MASK_STRING : '';
    },
  },
};
</script>
<template>
  <dl v-if="showSettings">
    <template v-for="{ label, value } in settings">
      <dt :key="`dt-${label}`">{{ label }}</dt>
      <dd :key="`dd-${label}`">{{ value }}</dd>
    </template>
  </dl>
</template>
