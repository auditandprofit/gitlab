<script>
import { s__ } from '~/locale';
import AnalyticsClipboardInput from '../../shared/analytics_clipboard_input.vue';

export default {
  name: 'ProductAnalyticsInstrumentationInstructionsSdkDetails',
  components: {
    AnalyticsClipboardInput,
  },
  inject: {
    collectorHost: {
      type: String,
    },
  },
  props: {
    trackingKey: {
      type: String,
      required: true,
    },
  },
  i18n: {
    sdkHost: s__('ProductAnalytics|SDK host'),
    sdkHostDescription: s__('ProductAnalytics|The receiver of tracking events'),
    sdkAppId: s__('ProductAnalytics|SDK application ID'),
    sdkAppIdDescription: s__('ProductAnalytics|The sender of tracking events'),
  },
};
</script>

<template>
  <section class="gl-mb-6 gl-flex gl-flex-wrap">
    <analytics-clipboard-input
      class="gl-mb-6 gl-mr-6 md:gl-mb-0"
      data-testid="sdk-host-container"
      :label="$options.i18n.sdkHost"
      :description="$options.i18n.sdkHostDescription"
      :value="collectorHost"
    />

    <analytics-clipboard-input
      data-testid="sdk-application-id-container"
      :label="$options.i18n.sdkAppId"
      :description="$options.i18n.sdkAppIdDescription"
      :value="trackingKey"
    />
  </section>
</template>
