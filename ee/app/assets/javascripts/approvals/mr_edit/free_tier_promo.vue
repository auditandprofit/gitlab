<script>
import { GlBanner, GlButton, GlLink, GlCollapse } from '@gitlab/ui';
import Tracking from '~/tracking';
import { s__ } from '~/locale';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import {
  MR_APPROVALS_PROMO_DISMISSED,
  MR_APPROVALS_PROMO_I18N,
  MR_APPROVALS_PROMO_TRACKING_EVENTS,
} from 'ee/approvals/constants';

const trackingMixin = Tracking.mixin({});

export default {
  components: {
    GlBanner,
    GlButton,
    GlLink,
    LocalStorageSync,
    GlCollapse,
  },
  mixins: [trackingMixin],
  inject: ['learnMorePath', 'promoImageAlt', 'promoImagePath', 'tryNowPath'],
  data() {
    return {
      // isReady - used to render components after local storage has synced
      isReady: false,
      // isExpanded - the current collapsible state
      isExpanded: true,
      // isBannerVisible - is the banner visible
      isBannerDismissed: false,
    };
  },
  computed: {
    icon() {
      return this.isExpanded ? 'chevron-down' : 'chevron-right';
    },
    buttonAttributes() {
      return {
        target: '_blank',
        'aria-label': s__('ApprovalRule|Learn more about merge request approval rules'),
        'data-track-action': this.$options.trackingEvents.tryNowClick.action,
        'data-track-label': this.$options.trackingEvents.tryNowClick.label,
        'data-testid': 'promo-dismiss-btn',
      };
    },
  },
  mounted() {
    this.$nextTick(this.ready);
  },
  methods: {
    ready() {
      this.isReady = true;
    },
    toggleCollapse() {
      // If we're expanded already, then the user tried to collapse...
      if (this.isExpanded) {
        const { action, ...options } = MR_APPROVALS_PROMO_TRACKING_EVENTS.collapsePromo;
        this.track(action, options);
      } else {
        const { action, ...options } = MR_APPROVALS_PROMO_TRACKING_EVENTS.expandPromo;
        this.track(action, options);
      }

      this.isExpanded = !this.isExpanded;
    },
    hideBanner() {
      this.isBannerDismissed = true;
      this.isExpanded = false;
    },
  },
  trackingEvents: MR_APPROVALS_PROMO_TRACKING_EVENTS,
  i18n: MR_APPROVALS_PROMO_I18N,
  MR_APPROVALS_PROMO_DISMISSED,
};
</script>

<template>
  <div class="gl-mt-2">
    <local-storage-sync
      v-model="isBannerDismissed"
      :storage-key="$options.MR_APPROVALS_PROMO_DISMISSED"
    />
    <template v-if="isReady">
      <p class="gl-mb-0 gl-text-subtle">
        {{ $options.i18n.summary }}
      </p>

      <gl-button
        v-if="!isBannerDismissed"
        variant="link"
        :icon="icon"
        data-testid="collapse-btn"
        @click="toggleCollapse"
      >
        {{ $options.i18n.accordionTitle }}
      </gl-button>

      <gl-collapse v-if="!isBannerDismissed" v-model="isExpanded">
        <gl-banner
          :title="$options.i18n.promoTitle"
          :svg-path="promoImagePath"
          :button-text="$options.i18n.tryNow"
          :button-link="tryNowPath"
          :button-attributes="buttonAttributes"
          class="gl-mt-3"
          data-testid="mr-approval-rules"
          @close="hideBanner"
        >
          <ul class="gl-mb-5 gl-list-inside gl-p-0">
            <li v-for="(statement, index) in $options.i18n.valueStatements" :key="index">
              {{ statement }}
            </li>
          </ul>

          <template #actions>
            <gl-link
              :href="learnMorePath"
              target="_blank"
              class="gl-ml-3"
              :data-track-action="$options.trackingEvents.learnMoreClick.action"
              :data-track-label="$options.trackingEvents.learnMoreClick.label"
            >
              {{ $options.i18n.learnMore }}
            </gl-link>
          </template>
        </gl-banner>
      </gl-collapse>
    </template>
  </div>
</template>
