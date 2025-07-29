<script>
import { GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import TierBadgePopover from './tier_badge_popover.vue';

export default {
  components: {
    GlBadge,
    TierBadgePopover,
  },
  mixins: [Tracking.mixin({ label: 'tier_badge' })],
  props: {
    tier: {
      type: String,
      required: false,
      default: s__('TierBadge|Free'),
    },
  },
  mounted() {
    this.trackRender();
  },
  methods: {
    trackRender() {
      this.track('render_badge');
    },
    trackHover() {
      this.track('render_flyout');
    },
  },
  popoverTriggerId: 'tier-badge-trigger-id',
};
</script>
<template>
  <span class="gl-ml-2 gl-flex gl-items-center" @mouseover="trackHover">
    <gl-badge :id="$options.popoverTriggerId" data-testid="tier-badge" variant="tier">
      {{ tier }}
    </gl-badge>
    <tier-badge-popover
      :popover-id="$options.popoverTriggerId"
      triggers="hover focus manual"
      :tier="tier"
    />
  </span>
</template>
