<script>
import { GlPopover, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import Tracking, { InternalEvents } from '~/tracking';
import { isExperimentVariant } from '~/experimentation/utils';
import DUO_CHAT_ILLUSTRATION from './popover-gradient.svg?url';

export const ASK_DUO_HOTSPOT_CSS_CLASS = 'js-ask-duo-hotspot';
export const DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS = 'js-tanuki-bot-chat-toggle';
const trackingMixin = InternalEvents.mixin();

const i18n = {
  POPOVER_LABEL: s__('DuoChat|AI features are now available'),
  POPOVER_DESCRIPTION: s__(
    'DuoChat|%{linkStart}Learn how%{linkEnd} to set up Code Suggestions and Chat in your IDE. You can also use Chat in GitLab. Ask questions about:',
  ),
  POPOVER_LIST_ITEMS: [
    s__("DuoChat|The issue, epic, merge request, or code you're viewing"),
    s__('DuoChat|How to use GitLab'),
  ],
  POPOVER_BUTTON: __('Ask GitLab Duo'),
};

export default {
  name: 'DuoChatCallout',
  components: {
    GlPopover,
    GlButton,
    GlSprintf,
    GlLink,
    UserCalloutDismisser,
  },
  mixins: [trackingMixin, Tracking.mixin({ experiment: 'hotspot_duo_chat_during_trial' })],
  computed: {
    isCandidate() {
      return isExperimentVariant('hotspot_duo_chat_during_trial');
    },
  },
  beforeMount() {
    this.hotspot = document.querySelector(`.${ASK_DUO_HOTSPOT_CSS_CLASS}`);

    const allButtons = Array.from(
      document.querySelectorAll(`.${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}`),
    );

    this.popoverTarget = allButtons.find((button) => {
      const style = window.getComputedStyle(button);
      return style.display !== 'none' && style.visibility !== 'hidden';
    });
  },
  mounted() {
    if (this.hotspot) {
      this.track('render_ask_gitlab_duo_hotspot');
    }

    if (this.isCandidate) {
      this.hotspot?.addEventListener('click', this.handleHotspotClick);
      this.popoverTarget?.addEventListener('click', this.handleCandidateButtonClick);
    } else {
      this.popoverTarget?.addEventListener('click', this.handleButtonClick);
    }
  },
  beforeDestroy() {
    this.stopListeningToPopover();
  },
  methods: {
    handleButtonClick() {
      if (this.$refs.popoverLink) {
        this.$refs.popoverLink.$emit('click');
      }

      this.handleCandidateButtonClick();
    },
    handleCandidateButtonClick() {
      this.track('click_button', { label: 'tanuki_bot_breadcrumbs_button' });
    },
    handleHotspotClick() {
      this.track('click_ask_gitlab_duo_hotspot');
    },
    stopListeningToPopover() {
      this.hotspot?.removeEventListener('click', this.handleHotspotClick);
      this.popoverTarget?.removeEventListener('click', this.handleCandidateButtonClick);
      this.popoverTarget?.removeEventListener('click', this.handleButtonClick);
    },
    dismissCallout(dismissFn, directClick = true) {
      this.stopListeningToPopover();
      dismissFn();

      if (directClick) {
        this.track('dismiss_duo_chat_callout');
      }

      if (this.isCandidate) {
        this.hotspot?.remove();
        this.hotspot = null;
      }
    },
    notifyAboutDismiss() {
      this.$emit('callout-dismissed');
    },
    dismissAndNotify(dismissFn) {
      this.dismissCallout(dismissFn, false);
      this.notifyAboutDismiss();
      this.track('click_ask_gitlab_duo');
    },
  },
  DUO_CHAT_ILLUSTRATION,
  i18n,
  learnHowPath: helpPagePath('user/gitlab_duo/_index'),
};
</script>
<template>
  <user-callout-dismisser v-if="popoverTarget" feature-name="duo_chat_callout">
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-popover
        v-if="shouldShowCallout"
        :target="isCandidate ? hotspot : popoverTarget"
        :show="shouldShowCallout && !isCandidate"
        :placement="isCandidate ? 'bottomleft' : 'bottom'"
        show-close-button
        :css-classes="[
          'js-duo-chat-callout-popover',
          'duo-chat-callout-popover',
          'gl-max-w-48',
          'gl-shadow-lg',
          'gl-p-2',
        ]"
        :triggers="isCandidate ? 'hover focus' : 'manual'"
        data-testid="duo-chat-promo-callout-popover"
        @close-button-clicked="dismissCallout(dismiss)"
        @shown="track('render_duo_chat_callout')"
      >
        <img
          :src="$options.DUO_CHAT_ILLUSTRATION"
          :alt="''"
          class="gl-pointer-events-none gl-absolute gl-left-0 gl-top-0 gl-w-full"
        />
        <h5 class="gl-my-3 gl-mr-3">
          {{ $options.i18n.POPOVER_LABEL }}
        </h5>
        <p class="gl-m-0 gl-w-7/10" data-testid="duo-chat-callout-description">
          <gl-sprintf :message="$options.i18n.POPOVER_DESCRIPTION">
            <template #link="{ content }">
              <gl-link
                :href="$options.learnHowPath"
                @click="trackEvent('click_learn_how_link_duo_chat_callout')"
                >{{ content }}</gl-link
              >
            </template>
          </gl-sprintf>
        </p>
        <ul class="gl-w-3/4 gl-pl-5 gl-pt-3">
          <li v-for="item in $options.i18n.POPOVER_LIST_ITEMS" :key="item">{{ item }}</li>
        </ul>
        <gl-button
          ref="popoverLink"
          variant="confirm"
          category="primary"
          class="gl-w-full"
          @click="dismissAndNotify(dismiss)"
        >
          {{ $options.i18n.POPOVER_BUTTON }}
        </gl-button>
      </gl-popover>
    </template>
  </user-callout-dismisser>
</template>
