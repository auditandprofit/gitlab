<script>
import { GlLink, GlSprintf, GlAlert } from '@gitlab/ui';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { ALERT_TEXT, DASHBOARD_SURVEY_LINK } from '../constants';

export default {
  name: 'ValueStreamFeedbackBanner',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    UserCalloutDismisser,
  },
  i18n: {
    alertText: ALERT_TEXT,
  },
  DASHBOARD_SURVEY_LINK,
};
</script>
<template>
  <user-callout-dismisser feature-name="vsd_feedback_banner">
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-alert
        v-if="shouldShowCallout"
        class="gl-my-4"
        data-testid="vsd-feedback-survey"
        @dismiss="dismiss"
      >
        <gl-sprintf :message="$options.i18n.alertText">
          <template #link="{ content }">
            <gl-link :href="$options.DASHBOARD_SURVEY_LINK">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </gl-alert>
    </template>
  </user-callout-dismisser>
</template>
