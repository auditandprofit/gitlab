<script>
import { GlFormInput, GlModal, GlSprintf } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { INDEX_ROUTE_NAME } from '../constants';
import deleteSecretMutation from '../graphql/mutations/delete_secret.mutation.graphql';

export default {
  name: 'SecretDeleteModal',
  components: {
    GlFormInput,
    GlModal,
    GlSprintf,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    secretName: {
      type: String,
      required: true,
    },
    showModal: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      typedSecretName: '',
    };
  },
  apollo: {},
  computed: {
    canDeleteSecret() {
      return this.typedSecretName === this.secretName;
    },
    modalOptions() {
      return {
        actionPrimary: {
          text: s__('Secrets|Delete secret'),
          attributes: {
            disabled: !this.canDeleteSecret,
            variant: 'danger',
          },
        },
        actionSecondary: {
          text: __('Cancel'),
          attributes: {
            variant: 'default',
          },
        },
      };
    },
  },
  methods: {
    handleDeleteError(message) {
      this.hideModal();
      createAlert({ message });
    },
    hideModal() {
      this.typedSecretName = '';
      this.$emit('hide');
    },
    showToastMessage() {
      const toastMessage = sprintf(s__('Secrets|Secret %{secretName} has been deleted.'), {
        secretName: this.secretName,
      });

      this.$emit('show-secrets-toast', toastMessage);
    },
    async deleteSecret() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteSecretMutation,
          variables: {
            fullPath: this.fullPath,
            name: this.secretName,
          },
        });

        const error = data.projectSecretDelete.errors[0];
        if (error) {
          this.handleDeleteError(error);
          return;
        }

        this.showToastMessage();
        this.typedSecretName = '';

        if (this.$route.meta.isRoot) {
          this.$emit('refetch-secrets');
        } else {
          this.$router.push({ name: INDEX_ROUTE_NAME });
        }
      } catch (e) {
        this.handleDeleteError(__('Something went wrong on our end. Please try again.'));
      }
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="showModal"
    :title="s__('Secrets|Delete Secret')"
    :action-primary="modalOptions.actionPrimary"
    :action-secondary="modalOptions.actionSecondary"
    modal-id="delete-secret-modal"
    @primary.prevent="deleteSecret"
    @secondary="hideModal"
    @canceled="hideModal"
    @hidden="hideModal"
  >
    <p data-testid="secret-delete-modal-description">
      <gl-sprintf
        :message="
          s__(
            `Secrets|Are you sure you want to delete secret %{secretName}? This action cannot be undone, and the secret cannot be recovered.`,
          )
        "
      >
        <template #secretName>
          <b>{{ secretName }}</b>
        </template>
      </gl-sprintf>
    </p>
    <p data-testid="secret-delete-modal-confirm-text">
      <gl-sprintf :message="s__(`Secrets|To confirm, enter %{secretName}:`)">
        <template #secretName>
          <code>{{ secretName }}</code>
        </template>
      </gl-sprintf>
    </p>
    <gl-form-input v-model="typedSecretName" type="text" />
  </gl-modal>
</template>
