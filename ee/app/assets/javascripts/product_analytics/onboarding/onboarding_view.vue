<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import OnboardingState from './components/onboarding_state.vue';
import ProviderSelectionView from './components/providers/provider_selection_view.vue';
import {
  STATE_LOADING_INSTANCE,
  STATE_CREATE_INSTANCE,
  STATE_WAITING_FOR_EVENTS,
} from './constants';

export default {
  name: 'ProductAnalyticsOnboardingView',
  components: {
    GlLoadingIcon,
    OnboardingState,
    ProviderSelectionView,
    OnboardingSetup: () => import('ee/product_analytics/onboarding/onboarding_setup.vue'),
  },
  inject: {
    dashboardsPath: {},
  },
  data() {
    return {
      state: '',
      pollState: false,
    };
  },
  computed: {
    loadingInstance() {
      return this.state === STATE_LOADING_INSTANCE;
    },
    showProviderSetup() {
      return this.state === STATE_CREATE_INSTANCE || this.loadingInstance;
    },
    showInstrumentationSetup() {
      return this.state === STATE_WAITING_FOR_EVENTS;
    },
  },
  methods: {
    onComplete() {
      this.$router.push({ name: 'index' });
    },
    onInitialized() {
      this.pollState = true;
    },
    showError(error, captureError = true, message = '') {
      createAlert({
        message: message || error.message,
        captureError,
        error,
      });
    },
  },
};
</script>

<template>
  <div>
    <onboarding-state
      v-model="state"
      :poll-state="pollState"
      @complete="onComplete"
      @error="
        showError(
          $event,
          false,
          s__(
            'ProductAnalytics|An error occurred while fetching data. Refresh the page to try again.',
          ),
        )
      "
    />

    <gl-loading-icon v-if="!state" size="lg" class="gl-my-7" />

    <provider-selection-view
      v-else-if="showProviderSetup"
      :loading-instance="loadingInstance"
      @initialized="onInitialized"
    />

    <onboarding-setup
      v-else-if="showInstrumentationSetup"
      is-initial-setup
      :dashboards-path="dashboardsPath"
    />
  </div>
</template>
