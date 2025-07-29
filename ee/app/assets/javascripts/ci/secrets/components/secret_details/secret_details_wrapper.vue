<script>
import { GlButton, GlDisclosureDropdown, GlLoadingIcon } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import { EDIT_ROUTE_NAME, FAILED_TO_LOAD_ERROR_MESSAGE } from '../../constants';
import getSecretDetailsQuery from '../../graphql/queries/get_secret_details.query.graphql';
import SecretDeleteModal from '../secret_delete_modal.vue';
import SecretDetails from './secret_details.vue';

export default {
  name: 'SecretDetailsWrapper',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlLoadingIcon,
    SecretDeleteModal,
    SecretDetails,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    routeName: {
      type: String,
      required: true,
    },
    secretName: {
      type: String,
      required: true,
    },
  },
  apollo: {
    secret: {
      skip() {
        return !this.secretName;
      },
      query: getSecretDetailsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          name: this.secretName,
        };
      },
      update(data) {
        return data.projectSecret || null;
      },
      error() {
        createAlert({ message: FAILED_TO_LOAD_ERROR_MESSAGE });
      },
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
    },
  },
  data() {
    return {
      secret: null,
      showDeleteModal: false,
    };
  },
  computed: {
    createdAtText() {
      const date = localeDateFormat.asDate.format(new Date(this.secret.createdAt));
      return sprintf(__('Created on %{date}'), { date });
    },
    disclosureDropdownOptions() {
      return [
        {
          text: __('Delete'),
          variant: 'danger',
          action: () => {
            this.showDeleteModal = true;
          },
        },
      ];
    },
    environmentLabelText() {
      const { environment } = this.secret;
      const environmentText = convertEnvironmentScope(environment).toLowerCase();
      return `${__('env')}::${environmentText}`;
    },
    isSecretLoading() {
      return this.$apollo.queries.secret.loading;
    },
  },
  methods: {
    goToEdit() {
      this.$router.push({ name: EDIT_ROUTE_NAME, params: { secretName: this.secretName } });
    },
    goTo(name) {
      if (this.routeName !== name) {
        this.$router.push({ name });
      }
    },
    hideModal() {
      this.showDeleteModal = false;
    },
  },
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="isSecretLoading" size="lg" class="gl-mt-6" />
    <div v-if="secret">
      <secret-delete-modal
        :full-path="fullPath"
        :secret-name="secret.name"
        :show-modal="showDeleteModal"
        @hide="hideModal"
        v-on="$listeners"
      />
      <div class="gl-flex gl-items-center gl-justify-between">
        <h1 class="page-title gl-text-size-h-display">{{ secret.name }}</h1>
        <div>
          <gl-button
            icon="pencil"
            :aria-label="__('Edit')"
            data-testid="secret-edit-button"
            @click="goToEdit"
          />
          <gl-disclosure-dropdown
            category="tertiary"
            icon="ellipsis_v"
            no-caret
            :items="disclosureDropdownOptions"
          />
        </div>
      </div>
      <secret-details :full-path="fullPath" :secret="secret" />
    </div>
  </div>
</template>
