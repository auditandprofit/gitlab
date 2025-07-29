<script>
import { GlIcon } from '@gitlab/ui';
import { __ } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { securityScannerOfGroupValidator } from 'ee/security_inventory/utils';

export default {
  name: 'GroupToolCoverageDetails',
  components: {
    GlIcon,
  },
  mixins: [timeagoMixin],
  props: {
    securityScanner: {
      type: Object,
      required: true,
      validator: (value) => securityScannerOfGroupValidator(value),
    },
  },
  data() {
    return {
      statusConfig: {
        success: { name: 'check-circle-filled', variant: 'success', text: __('Enabled') },
        failure: { name: 'status-failed', variant: 'danger', text: __('Failed') },
        notConfigured: { name: 'clear', variant: 'disabled', text: __('Not enabled') },
      },
    };
  },
  computed: {
    formattedDateUpdated() {
      return `${__('Date updated')} ${this.timeFormatted(this.securityScanner.updatedAt)}`;
    },
  },
  methods: {
    getStatusConfig(key) {
      return this.statusConfig[key] || this.statusConfig.notConfigured;
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-m-2">
      <div v-for="key in Object.keys(statusConfig)" :key="key" class="gl-my-2">
        <gl-icon
          :name="getStatusConfig(key).name"
          :variant="getStatusConfig(key).variant"
          :size="12"
          :data-testid="`icon-${key}`"
          :aria-label="getStatusConfig(key).text"
        />
        <span class="gl-font-bold" :data-testid="`scanner-title-${key}`"
          >{{ getStatusConfig(key).text }}:</span
        >
        <span :data-testid="`scanner-status-${key}`">
          {{ securityScanner[key] }}
        </span>
      </div>
    </div>

    <div
      v-if="securityScanner && securityScanner.updatedAt"
      class="gl-mb-2 gl-mt-3"
      data-testid="date-updated"
    >
      {{ formattedDateUpdated }}
    </div>
  </div>
</template>
