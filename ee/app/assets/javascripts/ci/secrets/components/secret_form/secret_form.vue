<script>
import {
  GlButton,
  GlCollapsibleListbox,
  GlDatepicker,
  GlDropdownDivider,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlLink,
  GlModal,
  GlSprintf,
} from '@gitlab/ui';
import { isDate } from 'lodash';
import { createAlert } from '~/alert';
import { __, s__, sprintf } from '~/locale';
import { getDateInFuture } from '~/lib/utils/datetime_utility';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import {
  DETAILS_ROUTE_NAME,
  INDEX_ROUTE_NAME,
  ROTATION_PERIOD_OPTIONS,
  SECRET_DESCRIPTION_MAX_LENGTH,
} from '../../constants';
import { convertRotationPeriod } from '../../utils';
import createSecretMutation from '../../graphql/mutations/create_secret.mutation.graphql';
import updateSecretMutation from '../../graphql/mutations/update_secret.mutation.graphql';
import SecretBranchesField from './secret_branches_field.vue';

export default {
  name: 'SecretForm',
  components: {
    CiEnvironmentsDropdown,
    GlButton,
    GlCollapsibleListbox,
    GlDropdownDivider,
    GlDatepicker,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlLink,
    GlModal,
    GlSprintf,
    SecretBranchesField,
  },
  props: {
    areEnvironmentsLoading: {
      type: Boolean,
      required: true,
    },
    environments: {
      type: Array,
      required: false,
      default: () => [],
    },
    fullPath: {
      type: String,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    secretData: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  data() {
    return {
      customRotationPeriod: '',
      isEditingValue: false,
      isSubmitting: false,
      secret: {
        branch: '',
        description: undefined,
        environment: '',
        expiration: undefined,
        name: undefined,
        rotationPeriod: '',
        secret: undefined, // shown as "value" in the UI
        ...this.secretData,
      },
      showConfirmEditModal: false,
    };
  },
  computed: {
    canSubmit() {
      return (
        this.isBranchValid &&
        this.isNameValid &&
        this.isValueValid &&
        this.isDescriptionValid &&
        this.isEnvironmentScopeValid
      );
    },
    isBranchValid() {
      return this.secret.branch.length > 0;
    },
    isDescriptionValid() {
      return (
        this.secret.description.length > 0 &&
        this.secret.description.length <= SECRET_DESCRIPTION_MAX_LENGTH
      );
    },
    isEnvironmentScopeValid() {
      return this.secret.environment.length > 0;
    },
    isExpirationValid() {
      return isDate(this.secret.expiration);
    },
    isNameValid() {
      return this.secret.name?.length > 0;
    },
    isValueFieldDisabled() {
      if (this.isEditing) {
        return !this.isEditingValue;
      }

      return false;
    },
    isValueValid() {
      if (this.isEditing) {
        return true; // value is optional when editing
      }

      return this.secret.secret.length > 0;
    },
    minExpirationDate() {
      // secrets can expire tomorrow, but not today or yesterday
      const today = new Date();
      return getDateInFuture(today, 1);
    },
    rotationPeriodText() {
      return convertRotationPeriod(this.secret.rotationPeriod);
    },
    rotationPeriodToggleText() {
      if (this.secret.rotationPeriod.length) {
        return this.rotationPeriodText;
      }

      return s__('Secrets|Select a reminder interval');
    },
    submitButtonText() {
      return this.isEditing ? __('Save changes') : s__('Secrets|Add secret');
    },
    valueFieldPlaceholder() {
      if (this.isEditing) {
        return '* * * * * * *';
      }

      return s__('Secrets|Enter a value for the secret');
    },
  },
  methods: {
    async createSecret() {
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createSecretMutation,
          variables: {
            projectPath: this.fullPath,
            ...this.secret,
          },
        });

        const error = data.projectSecretCreate.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        await this.$router.push({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: this.secret.name },
        });
      } catch (e) {
        createAlert({ message: __('Something went wrong on our end. Please try again.') });
      } finally {
        this.isSubmitting = false;
      }
    },
    disableValueEditing() {
      this.isEditingValue = false;
    },
    editValue() {
      this.isEditingValue = true;
      this.$nextTick(() => {
        this.$refs.editValueField.$el.focus();
      });
    },
    async editSecret() {
      this.hideModal();
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateSecretMutation,
          variables: {
            projectPath: this.fullPath,
            ...this.secret,
          },
        });

        const error = data.projectSecretUpdate.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        this.showUpdateToastMessage();
        await this.$router.push({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: this.secret.name },
        });
      } catch (e) {
        createAlert({ message: __('Something went wrong on our end. Please try again.') });
      } finally {
        this.isSubmitting = false;
      }
    },
    hideModal() {
      this.showConfirmEditModal = false;
    },
    setBranch(branch) {
      this.secret.branch = branch;
    },
    setCustomRotationPeriod() {
      this.secret.rotationPeriod = this.customRotationPeriod;
    },
    setEnvironment(environment) {
      this.secret.environment = environment;
    },
    showUpdateToastMessage() {
      const toastMessage = sprintf(s__('Secrets|Secret %{secretName} was successfully updated.'), {
        secretName: this.secret.name,
      });

      this.$emit('show-secrets-toast', toastMessage);
    },
    async submitSecret() {
      if (this.isEditing) {
        this.showConfirmEditModal = true;
      } else {
        await this.createSecret();
      }
    },
  },
  cronPlaceholder: '0 6 * * *',
  datePlaceholder: 'YYYY-MM-DD',
  i18n: {
    fieldRequired: __('This field is required.'),
  },
  modalOptions: {
    actionPrimary: {
      text: __('Save changes'),
    },
    actionSecondary: {
      text: __('Cancel'),
    },
  },
  rotationPeriodOptions: ROTATION_PERIOD_OPTIONS,
  secretsIndexRoute: INDEX_ROUTE_NAME,
};
</script>
<template>
  <div>
    <gl-form @submit.prevent="submitSecret">
      <gl-form-group
        v-if="!isEditing"
        data-testid="secret-name-field-group"
        label-for="secret-name"
        :label="__('Name')"
        :description="s__('Secrets|The name should be unique within this project.')"
        :invalid-feedback="$options.i18n.fieldRequired"
        :state="secret.name === undefined || isNameValid"
      >
        <gl-form-input
          id="secret-name"
          v-model="secret.name"
          :placeholder="__('Enter a name')"
          :state="secret.name === undefined || isNameValid"
        />
      </gl-form-group>
      <gl-form-group
        data-testid="secret-value-field-group"
        label-for="secret-value"
        :invalid-feedback="$options.i18n.fieldRequired"
      >
        <template #label>
          {{ __('Value') }}
          <gl-button
            v-if="isEditing"
            class="gl-mb-2 gl-ml-3"
            icon="pencil"
            variant="link"
            data-testid="edit-value-button"
            :aria-label="__('Edit value')"
            @click="editValue"
          >
            {{ __('Edit value') }}
          </gl-button>
        </template>
        <gl-form-textarea
          id="secret-value"
          ref="editValueField"
          v-model="secret.secret"
          rows="5"
          max-rows="15"
          no-resize
          :disabled="isValueFieldDisabled"
          :placeholder="valueFieldPlaceholder"
          :spellcheck="false"
          :state="secret.secret === undefined || isValueValid"
          @blur="disableValueEditing"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Description')"
        data-testid="secret-description-field-group"
        label-for="secret-description"
        :description="s__('Secrets|Maximum 200 characters.')"
        :invalid-feedback="
          s__('Secrets|This field is required and must be 200 characters or less.')
        "
      >
        <gl-form-input
          id="secret-description"
          v-model.trim="secret.description"
          data-testid="secret-description"
          :placeholder="s__('Secrets|Add a description for the secret')"
          :state="secret.description === undefined || isDescriptionValid"
        />
      </gl-form-group>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          :label="__('Environments')"
          label-for="secret-environments"
          class="gl-w-1/2 gl-pr-2"
        >
          <ci-environments-dropdown
            id="secret-environments"
            :are-environments-loading="areEnvironmentsLoading"
            :environments="environments"
            :selected-environment-scope="secret.environment"
            @select-environment="setEnvironment"
            @search-environment-scope="$emit('search-environment', $event)"
          />
        </gl-form-group>
        <gl-form-group :label="__('Branches')" label-for="secret-branches" class="gl-w-1/2 gl-pr-2">
          <secret-branches-field
            label-for="secret-branches"
            :full-path="fullPath"
            :selected-branch="secret.branch"
            @select-branch="setBranch"
          />
        </gl-form-group>
      </div>
      <div class="gl-flex gl-gap-4">
        <gl-form-group
          class="gl-w-full"
          label-for="secret-expiration"
          :label="__('Expiration date')"
        >
          <gl-datepicker
            id="secret-expiration"
            v-model="secret.expiration"
            class="gl-max-w-none"
            :placeholder="$options.datePlaceholder"
            :min-date="minExpirationDate"
          />
        </gl-form-group>
        <gl-form-group
          class="gl-w-full"
          :label="s__('Secrets|Rotation period')"
          label-for="secret-rotation-period"
          optional
        >
          <gl-collapsible-listbox
            id="secret-rotation-period"
            v-model.trim="secret.rotationPeriod"
            block
            :label-text="s__('Secrets|Rotation reminder')"
            :header-text="s__('Secrets|Intervals')"
            :toggle-text="rotationPeriodToggleText"
            :items="$options.rotationPeriodOptions"
            optional
          >
            <template #footer>
              <gl-dropdown-divider />
              <div class="gl-mx-3 gl-mb-4 gl-mt-3">
                <p class="gl-my-0 gl-py-0">{{ s__('Secrets|Add custom interval.') }}</p>
                <p class="gl-my-0 gl-py-0 gl-text-sm gl-text-subtle">
                  <gl-sprintf :message="__('Use CRON syntax. %{linkStart}Learn more.%{linkEnd}')">
                    <template #link="{ content }">
                      <gl-link href="https://crontab.guru/" target="_blank">{{ content }}</gl-link>
                    </template>
                  </gl-sprintf>
                </p>
                <gl-form-input
                  v-model="customRotationPeriod"
                  data-testid="secret-cron"
                  :placeholder="$options.cronPlaceholder"
                  class="gl-my-3"
                />
                <gl-button
                  class="gl-float-right"
                  data-testid="add-custom-rotation-button"
                  size="small"
                  variant="confirm"
                  :aria-label="__('Add interval')"
                  @click="setCustomRotationPeriod"
                >
                  {{ __('Add interval') }}
                </gl-button>
              </div>
            </template>
          </gl-collapsible-listbox>
        </gl-form-group>
      </div>
      <div class="gl-my-3">
        <gl-button
          variant="confirm"
          data-testid="submit-form-button"
          :aria-label="submitButtonText"
          :disabled="!canSubmit || isSubmitting"
          :loading="isSubmitting"
          @click="submitSecret"
        >
          {{ submitButtonText }}
        </gl-button>
        <gl-button
          :to="{ name: $options.secretsIndexRoute }"
          data-testid="cancel-button"
          class="gl-my-4"
          :aria-label="__('Cancel')"
          :disabled="isSubmitting"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
      <gl-modal
        modal-id="secret-confirm-edit"
        :visible="showConfirmEditModal"
        :title="__('Save changes')"
        :action-primary="$options.modalOptions.actionPrimary"
        :action-secondary="$options.modalOptions.actionSecondary"
        @primary.prevent="editSecret"
        @secondary="hideModal"
        @canceled="hideModal"
        @hidden="hideModal"
      >
        <gl-sprintf
          :message="
            s__(
              `Secrets|Are you sure you want to update secret %{secretName}? Saving these changes can cause disruptions, such as loss of access to connected services or failed deployments.`,
            )
          "
        >
          <template #secretName>
            <b>{{ secret.name }}</b>
          </template>
        </gl-sprintf>
      </gl-modal>
    </gl-form>
  </div>
</template>
