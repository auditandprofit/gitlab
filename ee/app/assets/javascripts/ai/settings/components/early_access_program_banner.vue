<script>
import { GlBanner } from '@gitlab/ui';
import { s__ } from '~/locale';
import { parseBoolean, getCookie, setCookie } from '~/lib/utils/common_utils';
import showToast from '~/vue_shared/plugins/global_toast';

export const EARLY_ACCESS_BANNER_COOKIE_KEY = 'duo_early_access_program_banner_dismissed';

export default {
  name: 'EarlyAccessProgramBanner',
  i18n: {
    sectionTitle: s__(
      'AiPowered|Participate in the Early Access Program and help make GitLab better',
    ),
    sectionBody: s__(
      'AiPowered|Help make the next releases of GitLab better. As a member of the GitLab Early Access Program, you can take part in shaping GitLab by letting us know what you think of GitLab Duo experimental and beta features. How does this program work?',
    ),
    sectionButtonText: s__('AiPowered|Enroll in the Early Access Program'),
    toastMessage: s__(
      'AiPowered|Early Access Program banner dismissed. You will not see it again for 7 days.',
    ),
  },
  components: {
    GlBanner,
  },
  inject: ['earlyAccessPath'],
  data() {
    return {
      bannerDismissed: parseBoolean(getCookie(EARLY_ACCESS_BANNER_COOKIE_KEY)) || false,
    };
  },
  methods: {
    dismissBanner() {
      setCookie(EARLY_ACCESS_BANNER_COOKIE_KEY, 'true', { expires: 7 });
      this.bannerDismissed = true;

      showToast(this.$options.i18n.toastMessage);
    },
  },
};
</script>
<template>
  <gl-banner
    v-if="!bannerDismissed"
    :title="$options.i18n.sectionTitle"
    :button-text="$options.i18n.sectionButtonText"
    :button-link="earlyAccessPath"
    :svg-path="null"
    variant="introduction"
    class="gl-border-default gl-bg-subtle"
    @close="dismissBanner"
  >
    <p>
      {{ $options.i18n.sectionBody }}
    </p>
  </gl-banner>
</template>
