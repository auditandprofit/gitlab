<script>
import { GlSprintf, GlLink, GlBanner, GlButton } from '@gitlab/ui';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __, s__ } from '~/locale';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { InternalEvents } from '~/tracking';
import axios from '~/lib/utils/axios_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DOCS_URL_IN_EE_DIR } from '~/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import { updateGroupSettings } from 'ee/api/groups_api';

export default {
  name: 'EnableDuoBanner',
  i18n: {
    enableCodeSuggestionsAndChatText: s__('AiPowered|Enable GitLab Duo Core'),
    bannerBody: s__(
      'AiPowered|Code Suggestions and Chat are now available in supported IDEs as part of GitLab Duo Core for all users of your %{plan} plan.',
    ),
    secondaryButtonText: s__('AiPowered|Learn more'),
    modalEnableButton: __('Enable'),
    modalBody: s__(
      `AiPowered|GitLab Duo Core will be available to all users in your %{plan} plan, including Chat and Code Suggestions in supported IDEs. %{eligibilityLinkStart}Eligibility requirements apply%{eligibilityLinkEnd}. By enabling GitLab Duo, you accept the %{aiLinkStart}GitLab AI functionality terms%{aiLinkEnd}.`,
    ),
    successMessage: __('GitLab Duo Core is now enabled.'),
    errorMessage: __(
      'An error occurred while trying to enable GitLab Duo Core. Reload the page to try again.',
    ),
  },
  components: {
    GlSprintf,
    GlLink,
    GlBanner,
    GlButton,
    ConfirmActionModal,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['bannerTitle', 'groupId', 'groupPlan', 'calloutsPath', 'calloutsFeatureName'],
  data() {
    return {
      isDismissed: false,
      isClosedByPrimaryModalBtn: false,
      showEnableDuoConfirmModal: false,
    };
  },
  mounted() {
    this.trackEvent('view_enable_duo_banner_pageload');
  },
  methods: {
    async handleEnableClick() {
      this.trackEvent('click_enable_button_enable_duo_banner_modal');

      this.isClosedByPrimaryModalBtn = true;

      try {
        await updateGroupSettings(this.groupId, {
          duo_core_features_enabled: true,
        });

        this.isDismissed = true;
        createAlert({
          message: this.$options.i18n.successMessage,
          variant: VARIANT_INFO,
        });
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
      }
    },
    primaryClicked() {
      this.trackEvent('click_primary_button_enable_duo_banner');
      this.showEnableDuoConfirmModal = true;
    },
    secondaryClicked() {
      this.trackEvent('click_secondary_button_enable_duo_banner');
      visitUrl(this.$options.learnMoreHref, { external: true });
    },
    dismissModal() {
      if (!this.isClosedByPrimaryModalBtn) {
        this.trackEvent('dismiss_enable_duo_banner_modal');
      }

      this.isClosedByPrimaryModalBtn = false;
      this.showEnableDuoConfirmModal = false;
    },
    dismissBanner() {
      this.postGroupCallout();

      this.isDismissed = true;
      this.trackEvent('dismiss_enable_duo_banner');
    },
    postGroupCallout() {
      axios
        .post(this.calloutsPath, {
          feature_name: this.calloutsFeatureName,
          group_id: this.groupId,
        })
        .catch((error) => {
          // eslint-disable-next-line @gitlab/require-i18n-strings, no-console
          console.error('Failed to dismiss banner.', error);
          Sentry.captureException(error);
        });
    },
  },
  learnMoreHref: `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo`,
  eligibilityHref: `${DOCS_URL_IN_EE_DIR}/subscriptions/subscription-add-ons/#gitlab-duo-core`,
};
</script>

<template>
  <div>
    <gl-banner
      v-if="!isDismissed"
      :title="bannerTitle"
      :button-text="$options.i18n.enableCodeSuggestionsAndChatText"
      class="custom-banner gl-mt-5 gl-bg-white"
      data-testid="enable-duo-banner"
      @primary="primaryClicked()"
      @close="dismissBanner()"
    >
      <p>
        <gl-sprintf :message="$options.i18n.bannerBody">
          <template #plan>
            {{ groupPlan }}
          </template>
        </gl-sprintf>
      </p>
      <template #actions>
        <gl-button
          class="gl-ml-4"
          variant="confirm"
          category="tertiary"
          @click="secondaryClicked()"
        >
          {{ $options.i18n.secondaryButtonText }}
        </gl-button>
      </template>
    </gl-banner>

    <confirm-action-modal
      v-if="showEnableDuoConfirmModal"
      modal-id="enable-duo-confirmation-modal"
      :title="$options.i18n.enableCodeSuggestionsAndChatText"
      :action-fn="handleEnableClick"
      :action-text="$options.i18n.modalEnableButton"
      variant="confirm"
      @close="dismissModal()"
    >
      <gl-sprintf :message="$options.i18n.modalBody">
        <template #plan>
          {{ groupPlan }}
        </template>
        <template #eligibilityLink="{ content }">
          <gl-link :href="$options.eligibilityHref" target="_blank">{{ content }}</gl-link>
        </template>
        <template #aiLink="{ content }">
          <gl-link
            href="https://handbook.gitlab.com/handbook/legal/ai-functionality-terms/"
            target="_blank"
            >{{ content }}</gl-link
          >
        </template>
      </gl-sprintf>
    </confirm-action-modal>
  </div>
</template>

<style scoped>
.custom-banner {
  background-image: url('duo_banner_background.svg?url');
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
}
</style>
