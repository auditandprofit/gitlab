<script>
import { GlAlert, GlPopover, GlBadge } from '@gitlab/ui';

import { epicCountPermissionText } from 'ee/vue_shared/components/epic_countables/constants';

export default {
  components: {
    GlAlert,
    GlPopover,
    GlBadge,
  },
  props: {
    healthStatus: {
      type: Object,
      required: true,
      default: () => ({}),
    },
  },
  computed: {
    hasHealthStatus() {
      const { issuesOnTrack, issuesNeedingAttention, issuesAtRisk } = this.healthStatus;
      const totalHealthStatuses = issuesOnTrack + issuesNeedingAttention + issuesAtRisk;
      return totalHealthStatuses > 0;
    },
  },
  i18n: {
    epicCountPermissionText,
  },
  badgeClasses: '!gl-ml-0 gl-mr-2 gl-font-bold',
};
</script>

<template>
  <div v-if="hasHealthStatus" ref="healthStatus" class="gl-inline-flex gl-items-center">
    <gl-popover :target="() => $refs.healthStatus" placement="top">
      <span
        ><strong>{{ healthStatus.issuesOnTrack }}</strong
        >&nbsp;<span>{{ __('issues on track') }}</span
        >,</span
      ><br />
      <span
        ><strong>{{ healthStatus.issuesNeedingAttention }}</strong
        >&nbsp;<span>{{ __('issues need attention') }}</span
        >,</span
      ><br />
      <span
        ><strong>{{ healthStatus.issuesAtRisk }}</strong
        >&nbsp;<span>{{ __('issues at risk') }}</span></span
      >
      <gl-alert :dismissible="false" class="gl-mt-3 gl-max-w-26">
        {{ $options.i18n.epicCountPermissionText }}
      </gl-alert>
    </gl-popover>

    <gl-badge :class="$options.badgeClasses" variant="success">
      {{ healthStatus.issuesOnTrack }}
      <span class="gl-sr-only">&nbsp;{{ __('issues on track') }}</span>
    </gl-badge>

    <gl-badge :class="$options.badgeClasses" variant="warning">
      {{ healthStatus.issuesNeedingAttention }}
      <span class="gl-sr-only">&nbsp;{{ __('issues need attention') }}</span>
    </gl-badge>

    <gl-badge :class="$options.badgeClasses" variant="danger">
      {{ healthStatus.issuesAtRisk }}
      <span class="gl-sr-only">&nbsp;{{ __('issues at risk') }}</span>
    </gl-badge>
  </div>
</template>
