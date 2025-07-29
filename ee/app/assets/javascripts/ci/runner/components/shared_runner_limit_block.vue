<script>
import { GlButton, GlAlert } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, sprintf } from '~/locale';

export default {
  components: {
    GlButton,
    GlAlert,
  },
  props: {
    quotaUsed: {
      type: Number,
      required: true,
    },
    quotaLimit: {
      type: Number,
      required: true,
    },
    subscriptionsMoreMinutesUrl: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    isExpired() {
      return this.artifact.expired;
    },
    runnersWarningMessage() {
      return sprintf(
        s__(
          'Runners|You have used %{quotaUsed} out of %{quotaLimit} of your instance runners compute minutes.',
        ),
        { quotaUsed: this.quotaUsed, quotaLimit: this.quotaLimit },
      );
    },
    runnersPath() {
      return helpPagePath('ci/runners/configure_runners', {
        anchor: 'set-the-maximum-job-timeout',
      });
    },
  },
};
</script>
<template>
  <gl-alert class="gl-my-5" variant="danger" :dismissible="false">
    <p>
      {{ runnersWarningMessage }}

      <template v-if="runnersPath">
        {{ __('For more information, go to the ') }}
        <a :href="runnersPath">{{ __('Runners page.') }}</a>
      </template>
    </p>
    <gl-button
      v-if="subscriptionsMoreMinutesUrl"
      variant="danger"
      category="secondary"
      :href="subscriptionsMoreMinutesUrl"
    >
      {{ __('Purchase more minutes') }}
    </gl-button>
  </gl-alert>
</template>
