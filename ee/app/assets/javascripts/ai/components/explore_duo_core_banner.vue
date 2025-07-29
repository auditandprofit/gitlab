<script>
import { GlBanner, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';
import { InternalEvents } from '~/tracking';

export default {
  name: 'ExploreDuoCoreBanner',
  i18n: {
    bannerBody: s__(
      'AiPowered|You now have access to GitLab Duo Chat and Code Suggestions in supported IDEs. To start using these features, %{link1Start}install the GitLab extension in your IDE%{link1End}. If you already have this extension installed, %{link2Start}explore what you can do with GitLab Duo Core%{link2End}.',
    ),
  },
  components: {
    GlBanner,
    GlLink,
    GlSprintf,
    UserCalloutDismisser,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    calloutFeatureName: {
      type: String,
      required: true,
      default: '',
    },
  },
  installExtensionLink: `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/#step-4-prepare-to-use-gitlab-duo-in-your-ide`,
  exploreGitLabDuoLink: `${DOCS_URL_IN_EE_DIR}/user/gitlab_duo/#summary-of-gitlab-duo-features`,
  ctaLink: `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/`,
  mounted() {
    this.trackEvent('render_duo_core_banner');
  },
  methods: {
    onInstallExtensionClick() {
      this.trackEvent('click_extension_link_on_duo_core_banner');
    },
    onExploreGitLabDuoClick() {
      this.trackEvent('click_explore_link_on_duo_core_banner');
    },
    handlePrimaryAction(dismiss) {
      this.trackEvent('click_cta_link_on_duo_core_banner');
      dismiss();
    },
    handleClose(dismiss) {
      this.trackEvent('click_dismiss_button_on_duo_core_banner');
      dismiss();
    },
  },
};
</script>

<template>
  <div>
    <user-callout-dismisser :feature-name="calloutFeatureName">
      <template #default="{ dismiss, shouldShowCallout }">
        <gl-banner
          v-if="shouldShowCallout"
          :title="s__('AiPowered|Get started with GitLab Duo')"
          class="explore-duo-core-banner gl-mb-5 gl-mt-5 gl-bg-white"
          :button-text="s__('AiPowered|Explore GitLab Duo Core')"
          :button-link="$options.ctaLink"
          @primary="handlePrimaryAction(dismiss)"
          @close="handleClose(dismiss)"
        >
          <p>
            <gl-sprintf :message="$options.i18n.bannerBody">
              <template #link1="{ content }">
                <gl-link
                  :href="$options.installExtensionLink"
                  target="_blank"
                  @click="onInstallExtensionClick"
                >
                  {{ content }}
                </gl-link>
              </template>
              <template #link2="{ content }">
                <gl-link
                  :href="$options.exploreGitLabDuoLink"
                  target="_blank"
                  @click="onExploreGitLabDuoClick"
                >
                  {{ content }}
                </gl-link>
              </template>
            </gl-sprintf>
          </p>
        </gl-banner>
      </template>
    </user-callout-dismisser>
  </div>
</template>

<style scoped>
.explore-duo-core-banner {
  background-image: url('duo_banner_background.svg?url');
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
}
</style>
