<script>
import { GlProgressBar, GlButton } from '@gitlab/ui';
import { snakeCase } from 'lodash';
import { sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import {
  TRIAL_WIDGET_REMAINING_DAYS,
  TRIAL_WIDGET_SEE_UPGRADE_OPTIONS,
  TRIAL_WIDGET_DISMISS,
  TRIAL_WIDGET_CONTAINER_ID,
  TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS,
  TRIAL_WIDGET_CLICK_DISMISS,
  HAND_RAISE_LEAD_ATTRIBUTES,
  TRIAL_TYPES_CONFIG,
} from './constants';
import TrialWidgetButtons from './trial_widget_buttons.vue';

export default {
  name: 'TrialWidget',
  components: {
    GlProgressBar,
    GlButton,
    TrialWidgetButtons,
  },

  mixins: [InternalEvents.mixin()],

  inject: {
    trialType: { default: '' },
    daysRemaining: { default: 0 },
    percentageComplete: { default: 0 },
    groupId: { default: '' },
    featureId: { default: '' },
    dismissEndpoint: { default: '' },
  },

  trialWidget: {
    containerId: TRIAL_WIDGET_CONTAINER_ID,
    dismissLabel: TRIAL_WIDGET_DISMISS,
    upgradeOptionsText: TRIAL_WIDGET_SEE_UPGRADE_OPTIONS,
    upgradeThresholdDays: TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS,
  },

  handRaiseLeadAttributes: HAND_RAISE_LEAD_ATTRIBUTES,

  data() {
    return {
      isDismissed: false,
    };
  },

  computed: {
    currentTrialType() {
      return TRIAL_TYPES_CONFIG[this.trialType];
    },
    widgetRemainingDays() {
      return sprintf(TRIAL_WIDGET_REMAINING_DAYS, {
        daysLeft: this.daysRemaining,
      });
    },
    widgetTitle() {
      return this.currentTrialType.widgetTitle;
    },
    expiredWidgetTitleText() {
      return this.currentTrialType.widgetTitleExpiredTrial;
    },
    isTrialActive() {
      return this.daysRemaining > 0;
    },
    isDismissable() {
      return this.groupId && this.featureId && this.dismissEndpoint;
    },
    trackingLabel() {
      return snakeCase(this.currentTrialType.name.toLowerCase());
    },
  },

  methods: {
    handleDismiss() {
      axios
        .post(this.dismissEndpoint, {
          feature_name: this.featureId,
          group_id: this.groupId,
        })
        .catch((error) => {
          Sentry.captureException(error);
        });

      this.isDismissed = true;

      this.trackEvent(TRIAL_WIDGET_CLICK_DISMISS, {
        label: this.trackingLabel,
      });
    },
  },
};
</script>

<template>
  <div
    v-if="!isDismissed"
    :id="$options.trialWidget.containerId"
    class="gl-m-2 !gl-items-start gl-rounded-tl-base gl-bg-default gl-pt-4 gl-shadow"
    data-testid="trial-widget-root-element"
  >
    <div data-testid="trial-widget-menu" class="gl-flex gl-w-full gl-flex-col gl-items-stretch">
      <div v-if="isTrialActive">
        <div class="gl-flex-column gl-w-full">
          <div data-testid="widget-title" class="gl-text-md gl-mb-4 gl-font-bold gl-text-default">
            {{ widgetTitle }}
          </div>
          <gl-progress-bar
            :value="percentageComplete"
            class="custom-gradient-progress gl-mb-4 gl-bg-status-brand dark:gl-bg-purple-900"
            aria-hidden="true"
          />
          <div class="gl-flex gl-w-full gl-justify-between">
            <span class="gl-text-sm gl-text-subtle">
              {{ widgetRemainingDays }}
            </span>
          </div>
          <trial-widget-buttons data-testid="widget-cta" />
        </div>
      </div>
      <div v-else class="gl-flex gl-w-full gl-gap-4 gl-px-2">
        <div class="gl-w-full">
          <div data-testid="widget-title" class="gl-w-9/10 gl-text-sm gl-text-subtle">
            {{ expiredWidgetTitleText }}
          </div>
          <div class="gl-mt-4 gl-text-center">
            <gl-progress-bar
              :value="100"
              class="custom-gradient-progress gl-mb-4"
              aria-hidden="true"
            />
            <trial-widget-buttons data-testid="widget-cta" />
          </div>
        </div>
      </div>
    </div>
    <gl-button
      v-if="isDismissable && !isTrialActive"
      class="gl-absolute gl-right-0 gl-top-0 gl-mr-2 gl-mt-2"
      size="small"
      icon="close"
      category="tertiary"
      data-testid="dismiss-btn"
      :aria-label="$options.trialWidget.dismissLabel"
      @click="handleDismiss"
    />
  </div>
</template>
