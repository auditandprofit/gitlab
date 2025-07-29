<script>
import { GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  ACTION_ENABLE_SECRET_MANAGER,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_INACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import PermissionsSettings from './components/secrets_manager_permissions_settings.vue';

export const POLL_INTERVAL = 2000;

export default {
  name: 'SecretsManagerSettings',
  components: {
    GlToggle,
    PermissionsSettings,
  },
  provide() {
    const { fullPath, projectId } = this;
    return { fullPath, projectId };
  },
  props: {
    canManageSecretsManager: {
      type: Boolean,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    projectId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      action: null,
      hasError: false,
      secretManagerStatus: SECRET_MANAGER_STATUS_INACTIVE,
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
        const newStatus = projectSecretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;

        if (newStatus !== SECRET_MANAGER_STATUS_PROVISIONING) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
        }

        if (this.isEnablingSecretsManager && newStatus === SECRET_MANAGER_STATUS_ACTIVE) {
          this.$toast.show(s__('Secrets|Secrets Manager has been provisioned for this project.'));
        }

        return newStatus;
      },
      error() {
        this.$apollo.queries.secretManagerStatus.stopPolling(POLL_INTERVAL);
        this.hasError = true;

        if (this.isEnablingSecretsManager) {
          this.secretManagerStatus = SECRET_MANAGER_STATUS_INACTIVE;
        }
      },
      pollInterval: POLL_INTERVAL,
    },
  },
  computed: {
    isActive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_ACTIVE;
    },
    isEnablingSecretsManager() {
      return this.action === ACTION_ENABLE_SECRET_MANAGER;
    },
    isInactive() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_INACTIVE;
    },
    isLoading() {
      return this.$apollo.queries.secretManagerStatus.loading;
    },
    isProvisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_PROVISIONING;
    },
    isToggleDisabled() {
      return (
        this.isLoading || this.isProvisioning || this.isActive || !this.canManageSecretsManager
      );
    },
    isToggleLoading() {
      return this.isLoading || this.isProvisioning;
    },
  },
  methods: {
    async enableProjectSecretsManager() {
      this.hasError = false;
      try {
        const {
          data: {
            projectSecretsManagerInitialize: { errors, projectSecretsManager },
          },
        } = await this.$apollo.mutate({
          mutation: enableSecretManagerMutation,
          variables: {
            projectPath: this.fullPath,
          },
        });

        if (errors.length > 0) {
          throw new Error(errors[0]);
        }

        this.secretManagerStatus = projectSecretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;
        this.$apollo.queries.secretManagerStatus.startPolling(POLL_INTERVAL);
      } catch (error) {
        this.hasError = true;
      }
    },
    onToggleSecretManager() {
      if (this.isInactive) {
        this.action = ACTION_ENABLE_SECRET_MANAGER;
        this.enableProjectSecretsManager();
      }
    },
  },
};
</script>

<template>
  <div data-testid="secret-manager">
    <label class="gl-mb-1 gl-mr-3">
      {{ s__('Secrets|Secrets Manager') }}
    </label>
    <p class="gl-mb-2">
      {{
        s__(
          'Secrets|Enable the Secrets Manager to securely store and manage sensitive information for this project.',
        )
      }}
    </p>
    <gl-toggle
      :value="isActive"
      :label="s__('Secrets|Secrets Manager')"
      :disabled="isToggleDisabled"
      :is-loading="isToggleLoading"
      label-position="hidden"
      name="secret_manager_enabled"
      data-testid="secret-manager-toggle"
      @change="onToggleSecretManager"
    />
    <p v-if="hasError" class="gl-mt-2 gl-text-danger" data-testid="secret-manager-error">
      {{ __('Something went wrong. Please try again.') }}
    </p>
    <permissions-settings v-if="isActive" :can-manage-secrets-manager="canManageSecretsManager" />
  </div>
</template>
