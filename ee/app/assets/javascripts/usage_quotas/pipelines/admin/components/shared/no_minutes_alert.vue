<script>
import { GlAlert } from '@gitlab/ui';

export default {
  components: {
    GlAlert,
  },
};
</script>

<template>
  <gl-alert :dismissible="false">
    {{ s__('UsageQuota|No compute usage data available.') }}
  </gl-alert>
</template>
