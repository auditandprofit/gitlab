<script>
import { GlBanner } from '@gitlab/ui';
import ChatBubbleSvg from '@gitlab/svgs/dist/illustrations/chat-sm.svg?url';
import { __, s__ } from '~/locale';
import { GEO_FEEDBACK_BANNER_DISMISSED_KEY } from '../constants';

export default {
  name: 'GeoFeedbackBanner',
  components: {
    GlBanner,
  },
  data() {
    return {
      isFeedbackBannerDismissed: localStorage.getItem(GEO_FEEDBACK_BANNER_DISMISSED_KEY) === 'true',
    };
  },
  methods: {
    handleDismissBanner() {
      localStorage.setItem(GEO_FEEDBACK_BANNER_DISMISSED_KEY, 'true');
      this.isFeedbackBannerDismissed = true;
    },
  },
  i18n: {
    banner: {
      title: __('Your feedback is important to us 👋'),
      description: s__(
        'Geo|Help us improve Geo for distributed teams and disaster recovery. We aim to make it simpler to use and operate.',
      ),
      btnText: __('Give us some feedback'),
    },
  },
  ChatBubbleSvg,
};
</script>
<template>
  <div>
    <gl-banner
      v-if="!isFeedbackBannerDismissed"
      class="gl-mt-5"
      :title="$options.i18n.banner.title"
      :button-text="$options.i18n.banner.btnText"
      button-link="https://gitlab.com/gitlab-org/gitlab/-/issues/536297"
      :svg-path="$options.ChatBubbleSvg"
      @close="handleDismissBanner"
    >
      <p>
        {{ $options.i18n.banner.description }}
      </p>
    </gl-banner>
  </div>
</template>
