<script>
import { GlButton, GlCard, GlIntersectionObserver } from '@gitlab/ui';
import TANUNKI_AI_ICON from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { SUPPORT_URL } from '~/sessions/new/constants';
import Tracking from '~/tracking';

export default {
  name: 'DuoCoreUpgradeCard',
  components: {
    GlButton,
    GlCard,
    GlIntersectionObserver,
  },
  mixins: [Tracking.mixin()],
  inject: ['addDuoProHref'],
  methods: {
    trackPageView() {
      this.track('pageview', { label: 'duo_core_add_on_upgrade_card' });
    },
    trackPurchaseSeatsClick() {
      this.track('click_button', { label: 'duo_pro_purchase_seats' });
    },
    trackEnterpriseContactSales() {
      this.track('click_button', { label: 'duo_enterprise_contact_sales' });
    },
  },
  TANUNKI_AI_ICON,
  SUPPORT_URL,
};
</script>
<template>
  <gl-intersection-observer @appear.once="trackPageView">
    <gl-card
      footer-class="gl-bg-transparent gl-border-none gl-flex-end gl-flex gl-flex-wrap gl-gap-3"
      class="gl-justify-between"
    >
      <template #default>
        <div class="gl-flex">
          <img
            :src="$options.TANUNKI_AI_ICON"
            :alt="s__('AiPowered|Tanuki AI icon')"
            class="gl-pointer-events-none gl-size-10"
          />
          <div class="gl-ml-4">
            <h2 class="gl-m-0 gl-text-lg">{{ s__('AiPowered|Upgrade to') }}</h2>
            <p class="gl-mb-3 gl-text-size-h-display gl-font-bold">
              {{ s__('AiPowered|GitLab Duo Pro or Enterprise') }}
            </p>
          </div>
        </div>
        <p class="gl-mb-0 gl-mt-3">
          {{
            s__(
              'AiPowered|Unlock advanced AI-native capabilities with the Premium or Ultimate tier designed for your development needs.',
            )
          }}
        </p>
      </template>
      <template #footer>
        <gl-button
          :href="addDuoProHref"
          target="_blank"
          rel="noopener noreferrer"
          variant="confirm"
          category="primary"
          data-testid="duo-core-upgrade-duo-pro-action"
          @click="trackPurchaseSeatsClick"
        >
          {{ s__('AiPowered|Purchase Duo Pro seats') }}
        </gl-button>

        <gl-button
          :href="$options.SUPPORT_URL"
          target="_blank"
          rel="noopener noreferrer"
          variant="default"
          category="secondary"
          data-testid="duo-core-upgrade-duo-enterprise-action"
          @click="trackEnterpriseContactSales"
        >
          {{ s__('AiPowered|Contact sales for Duo Enterprise') }}
        </gl-button>
      </template>
    </gl-card>
  </gl-intersection-observer>
</template>
