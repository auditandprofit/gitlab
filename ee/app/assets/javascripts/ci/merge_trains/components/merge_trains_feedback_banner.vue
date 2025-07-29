<script>
import { GlBanner } from '@gitlab/ui';
import MergeTrainSvg from '@gitlab/svgs/dist/illustrations/train-sm.svg?url';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

export default {
  name: 'MergeTrainsFeedbackBanner',
  components: {
    GlBanner,
    LocalStorageSync,
  },
  data() {
    return {
      bannerClosed: false,
    };
  },
  methods: {
    handleBannerClose() {
      this.bannerClosed = true;
    },
  },
  MergeTrainSvg,
  MERGE_TRAINS_STORAGE_KEY: 'merge_trains_viz_feedback_banner',
};
</script>

<template>
  <local-storage-sync v-model="bannerClosed" :storage-key="$options.MERGE_TRAINS_STORAGE_KEY">
    <gl-banner
      v-if="!bannerClosed"
      class="gl-mt-4"
      variant="introduction"
      :title="__('Tell us what you think')"
      :button-text="__('Give feedback')"
      button-link="https://gitlab.com/gitlab-org/gitlab/-/issues/464774"
      :svg-path="$options.MergeTrainSvg"
      @close="handleBannerClose"
    >
      <p>
        {{ __('Help us improve the merge train visualization by sharing your feedback with us.') }}
      </p>
    </gl-banner>
  </local-storage-sync>
</template>
