<script>
import { GlLink, GlButton } from '@gitlab/ui';
import { snakeCase } from 'lodash';
import { InternalEvents } from '~/tracking';
import {
  TRIAL_TYPES_CONFIG,
  TRIAL_WIDGET_CLICK_LEARN_MORE,
  TRIAL_WIDGET_CLICK_UPGRADE,
} from './constants';

export default {
  name: 'TrialWidgetButtons',
  handRaiseLeadAttributes: {
    variant: 'link',
    category: 'tertiary',
    size: 'small',
  },
  components: {
    GlLink,
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    trialType: { default: '' },
    purchaseNowUrl: { default: '' },
    trialDiscoverPagePath: { default: '' },
  },
  computed: {
    trackingLabel() {
      return snakeCase(TRIAL_TYPES_CONFIG[this.trialType].name.toLowerCase());
    },
  },
  methods: {
    handleUpgrade() {
      this.trackEvent(TRIAL_WIDGET_CLICK_UPGRADE, {
        label: this.trackingLabel,
      });
    },
    handleLearnMore() {
      this.trackEvent(TRIAL_WIDGET_CLICK_LEARN_MORE, {
        label: this.trackingLabel,
      });
    },
  },
};
</script>

<template>
  <div class="gl-mt-4 gl-flex gl-w-full gl-items-center gl-justify-between">
    <gl-link
      :href="trialDiscoverPagePath"
      class="gl-ml-3 gl-text-sm gl-no-underline hover:gl-no-underline"
      size="small"
      data-testid="learn-about-features-btn"
      @click.stop="handleLearnMore"
    >
      {{ s__('TrialWidget|Learn more') }}
    </gl-link>

    <gl-button
      :href="purchaseNowUrl"
      size="small"
      variant="confirm"
      data-testid="upgrade-options-btn"
      @click.stop="handleUpgrade"
    >
      {{ s__('TrialWidget|Upgrade') }}
    </gl-button>
  </div>
</template>
