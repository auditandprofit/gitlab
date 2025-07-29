<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'ValidityCheckRefresh',
  components: {
    GlButton,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    findingTokenStatus: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      isLoading: false,
    };
  },
  computed: {
    lastCheckedAt() {
      return this.findingTokenStatus?.updatedAt;
    },
  },
};
</script>

<template>
  <div class="gl-mt-4">
    <span class="gl-font-sm gl-ml-2 gl-mr-2" data-testid="validity-last-checked">
      {{ s__('VulnerabilityManagement|Last checked:') }}
      <template v-if="lastCheckedAt">
        <time-ago-tooltip :time="lastCheckedAt" />
      </template>
      <template v-else>
        <span>{{ s__('VulnerabilityManagement|not available') }}</span>
      </template>
    </span>
    <gl-button
      v-gl-tooltip
      :loading="isLoading"
      category="tertiary"
      size="small"
      icon="retry"
      :title="s__('VulnerabilityManagement|Retry')"
      :aria-label="s__('VulnerabilityManagement|Retry')"
    />
  </div>
</template>
