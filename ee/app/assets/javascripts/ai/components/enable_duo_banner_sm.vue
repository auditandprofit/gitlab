<script>
import { GlSprintf, GlLink, GlBanner, GlButton } from '@gitlab/ui';
import { sprintf } from '@gitlab/ui/dist/utils/i18n';
import { createAlert, VARIANT_INFO } from '~/alert';
import { __, s__ } from '~/locale';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';
import updateAiSettingsMutation from '../graphql/update_ai_settings.mutation.graphql';

export default {
  name: 'EnableDuoBannerSM',
  i18n: {
    enableCodeSuggestionsAndChatText: s__('AiPowered|Enable GitLab Duo Core'),
    secondaryButtonText: s__('AiPowered|Learn more'),
    modalEnableButton: __('Enable'),
    modalBody: s__(
      'AiPowered|GitLab Duo Core will be available to all users in your %{plan} plan, including Chat and Code Suggestions in supported IDEs. %{eligibilityLinkStart}Eligibility requirements apply%{eligibilityLinkEnd}. By enabling GitLab Duo, you accept the %{aiLinkStart}GitLab AI functionality terms%{aiLinkEnd}.',
    ),
  },
  learnMoreHref: `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo`,
  eligibilityHref: `${DOCS_URL_IN_EE_DIR}/subscriptions/subscription-add-ons/#gitlab-duo-core`,
  components: {
    GlSprintf,
    GlLink,
    GlBanner,
    GlButton,
    ConfirmActionModal,
    UserCalloutDismisser,
  },
  inject: ['bannerTitle', 'licenseTier', 'calloutsFeatureName'],
  data() {
    return {
      isDismissed: false,
      showEnableDuoConfirmModal: false,
    };
  },
  computed: {
    bannerBody() {
      return sprintf(
        s__(
          'AiPowered|Code Suggestions and Chat are now available in supported IDEs as part of GitLab Duo Core for all users of your %{plan} plan.',
        ),
        { plan: this.licenseTier },
      );
    },
  },
  methods: {
    async handleEnableClick() {
      try {
        await this.enableDuoCore();

        this.isDismissed = true;

        createAlert({
          message: __('GitLab Duo Core is now enabled.'),
          variant: VARIANT_INFO,
        });
      } catch (error) {
        createAlert({
          message: __(
            'An error occurred while enabling GitLab Duo Core. Reload the page to try again.',
          ),
          captureError: true,
          error,
        });
      }
    },
    primaryClicked() {
      this.showEnableDuoConfirmModal = true;
    },
    dismissModal() {
      this.showEnableDuoConfirmModal = false;
    },
    async enableDuoCore() {
      const { data } = await this.$apollo.mutate({
        mutation: updateAiSettingsMutation,
        variables: {
          input: {
            duoCoreFeaturesEnabled: true,
          },
        },
      });

      if (data) {
        const { errors } = data.duoSettingsUpdate;

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }
      }
    },
  },
};
</script>

<template>
  <div>
    <user-callout-dismisser :feature-name="calloutsFeatureName">
      <template #default="{ dismiss, shouldShowCallout }">
        <gl-banner
          v-if="shouldShowCallout && !isDismissed"
          :title="bannerTitle"
          :button-text="$options.i18n.enableCodeSuggestionsAndChatText"
          class="custom-banner gl-mb-5 gl-mt-5 gl-bg-white"
          data-testid="enable-duo-banner-sm"
          @primary="primaryClicked"
          @close="dismiss"
        >
          <p>{{ bannerBody }}</p>
          <template #actions>
            <gl-button
              class="gl-ml-4"
              variant="confirm"
              category="tertiary"
              :href="$options.learnMoreHref"
              data-testid="enable-duo-banner-learn-more-button"
            >
              {{ $options.i18n.secondaryButtonText }}
            </gl-button>
          </template>
        </gl-banner>
      </template>
    </user-callout-dismisser>

    <confirm-action-modal
      v-if="showEnableDuoConfirmModal"
      modal-id="enable-duo-confirmation-modal"
      :title="$options.i18n.enableCodeSuggestionsAndChatText"
      :action-fn="handleEnableClick"
      :action-text="$options.i18n.modalEnableButton"
      variant="confirm"
      @close="dismissModal"
    >
      <gl-sprintf :message="$options.i18n.modalBody">
        <template #plan>
          {{ licenseTier }}
        </template>
        <template #eligibilityLink="{ content }">
          <gl-link :href="$options.eligibilityHref">{{ content }}</gl-link>
        </template>
        <template #aiLink="{ content }">
          <gl-link href="https://handbook.gitlab.com/handbook/legal/ai-functionality-terms/">{{
            content
          }}</gl-link>
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
