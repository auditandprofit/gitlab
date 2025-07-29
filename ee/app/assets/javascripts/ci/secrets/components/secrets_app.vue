<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import getSecretManagerStatusQuery from '../graphql/queries/get_secret_manager_status.query.graphql';
import { POLL_INTERVAL, SECRET_MANAGER_STATUS_PROVISIONING } from '../constants';

export default {
  name: 'SecretsApp',
  components: {
    GlLoadingIcon,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      secretManagerStatus: null,
    };
  },
  apollo: {
    secretManagerStatus: {
      query: getSecretManagerStatusQuery,
      variables() {
        return {
          projectPath: this.fullPath,
        };
      },
      update({ projectSecretsManager }) {
        const newStatus = projectSecretsManager?.status;

        if (newStatus !== SECRET_MANAGER_STATUS_PROVISIONING) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
        }

        return newStatus;
      },
      error(error) {
        createAlert({
          message: s__(
            'Secrets|An error occurred while fetching the Secret manager status. Please try again.',
          ),
        });
        captureException(error);
      },
      pollInterval: POLL_INTERVAL,
    },
  },
  computed: {
    isProvisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_PROVISIONING;
    },
  },
  methods: {
    showSecretsToast(message) {
      this.$toast.show(message);
    },
  },
};
</script>
<template>
  <gl-loading-icon
    v-if="!secretManagerStatus"
    data-testid="secrets-manager-loading-status"
    class="gl-mt-5"
  />
  <div
    v-else-if="isProvisioning"
    data-testid="secrets-manager-provisioning-text"
    class="gl-mt-5 gl-text-center"
  >
    <div class="gl-flex gl-items-center gl-justify-center">
      <gl-loading-icon class="gl-mr-3 gl-mt-1" />
      <p class="gl-mb-0 gl-inline gl-text-size-h1 gl-font-semibold">
        {{ s__('Secrets|Provisioning in progress') }}
      </p>
    </div>
    <p class="gl-mt-4 gl-text-secondary">
      {{
        s__('Secrets|Please wait while we provision the Secrets Manager for you. Refresh at will.')
      }}
    </p>
  </div>
  <router-view v-else ref="router-view" @show-secrets-toast="showSecretsToast" />
</template>
