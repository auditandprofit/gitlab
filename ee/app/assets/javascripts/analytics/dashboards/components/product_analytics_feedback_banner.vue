<script>
import { GlBanner } from '@gitlab/ui';
import ChatBubbleSvg from '@gitlab/svgs/dist/illustrations/chat-sm.svg?url';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import {
  PRODUCT_ANALYTICS_DASHBOARD_FEEDBACK_CALLOUT_ID,
  PRODUCT_ANALYTICS_DASHBOARD_SURVEY_LINK,
} from '../constants';

export default {
  name: 'ProductAnalyticsFeedbackBanner',
  components: {
    GlBanner,
    UserCalloutDismisser,
  },
  PRODUCT_ANALYTICS_DASHBOARD_FEEDBACK_CALLOUT_ID,
  PRODUCT_ANALYTICS_DASHBOARD_SURVEY_LINK,
  ChatBubbleSvg,
};
</script>

<template>
  <user-callout-dismisser :feature-name="$options.PRODUCT_ANALYTICS_DASHBOARD_FEEDBACK_CALLOUT_ID">
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-banner
        v-if="shouldShowCallout"
        :title="s__('ProductAnalytics|Tell us what you think!')"
        :button-text="__('Give feedback')"
        :svg-path="$options.ChatBubbleSvg"
        :dismiss-label="__('Dismiss')"
        :button-link="$options.PRODUCT_ANALYTICS_DASHBOARD_SURVEY_LINK"
        class="gl-my-4"
        @close="dismiss"
      >
        <p>
          {{
            s__(
              'ProductAnalytics|Help us improve Product Analytics Dashboards by sharing your experience.',
            )
          }}
        </p>
      </gl-banner>
    </template>
  </user-callout-dismisser>
</template>
