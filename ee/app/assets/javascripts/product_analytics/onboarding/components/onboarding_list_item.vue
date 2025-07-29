<script>
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

import AnalyticsFeatureListItem from 'ee/analytics/analytics_dashboards/components/list/feature_list_item.vue';
import {
  STATE_COMPLETE,
  STATE_WAITING_FOR_EVENTS,
  STATE_LOADING_INSTANCE,
  STATE_CREATE_INSTANCE,
} from '../constants';
import OnboardingState from './onboarding_state.vue';

export default {
  name: 'ProductAnalyticsOnboardingListItem',
  components: {
    OnboardingState,
    AnalyticsFeatureListItem,
  },
  inject: { canConfigureProjectSettings: {} },
  data() {
    return {
      state: '',
    };
  },
  computed: {
    needsSetup() {
      return this.state && this.state !== STATE_COMPLETE;
    },
    badge() {
      if (!this.canConfigureProjectSettings) {
        return {
          text: s__('ProductAnalytics|Additional permissions required'),
          popoverText: s__(
            'ProductAnalytics|Contact the GitLab administrator or project maintainer to onboard this project with product analytics. %{linkStart}Learn more%{linkEnd}.',
          ),
          popoverLink: helpPagePath('development/internal_analytics/product_analytics', {
            anchor: 'onboard-a-gitlab-project',
          }),
        };
      }

      switch (this.state) {
        case STATE_WAITING_FOR_EVENTS:
          return {
            text: s__('ProductAnalytics|Waiting for events'),
            popoverText: s__(
              'ProductAnalytics|An analytics provider has been successfully created, but it has not received any events yet. To continue with the setup, instrument your application and start sending events.',
            ),
          };
        case STATE_LOADING_INSTANCE:
          return {
            text: s__('ProductAnalytics|Loading instance'),
            popoverText: s__(
              'ProductAnalytics|The system is creating your analytics provider. In the meantime, you can instrument your application.',
            ),
          };
        default:
          return {};
      }
    },
    actionText() {
      return this.state === STATE_CREATE_INSTANCE
        ? __('Set up')
        : s__('ProductAnalytics|Continue set up');
    },
    actionDisabled() {
      return !this.canConfigureProjectSettings;
    },
  },
  methods: {
    onError(error) {
      this.$emit(
        'error',
        error,
        true,
        s__(
          'ProductAnalytics|An error occurred while fetching data. Refresh the page to try again.',
        ),
      );
    },
  },
  onboardingRoute: 'product-analytics-onboarding',
};
</script>

<template>
  <onboarding-state v-model="state" @complete="$emit('complete')" @error="onError">
    <analytics-feature-list-item
      v-if="needsSetup"
      :title="__('Product Analytics')"
      :description="
        s__(
          'ProductAnalytics|Track the performance of your product, and optimize your product and development processes.',
        )
      "
      :badge-text="badge.text"
      :badge-popover-text="badge.popoverText"
      :badge-popover-link="badge.popoverLink"
      :to="$options.onboardingRoute"
      :action-text="actionText"
      :action-disabled="actionDisabled"
    />
  </onboarding-state>
</template>
