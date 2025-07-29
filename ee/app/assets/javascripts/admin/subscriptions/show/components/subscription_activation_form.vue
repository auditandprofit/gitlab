<script>
import { GlButton, GlForm, GlFormCheckbox, GlFormGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import validation from '~/vue_shared/directives/validation';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import {
  activateLabel,
  INVALID_CODE_ERROR,
  INVALID_ACTIVATION_CODE_SERVER_ERROR,
  SUBSCRIPTION_ACTIVATION_FAILURE_EVENT,
  SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT,
  SUBSCRIPTION_ACTIVATION_FINALIZED_EVENT,
  subscriptionActivationForm,
  subscriptionActivationInsertCode,
} from '../constants';
import { getErrorsAsData, getLicenseFromData } from '../utils';
import activateSubscriptionMutation from '../graphql/mutations/activate_subscription.mutation.graphql';

const feedbackMap = {
  valueMissing: {
    isInvalid: (el) => el.validity?.valueMissing,
  },
  patternMismatch: {
    isInvalid: (el) => el.validity?.patternMismatch,
  },
};

export default {
  name: 'SubscriptionActivationForm',
  components: {
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormCheckbox,
    GlSprintf,
    PromoPageLink,
  },
  i18n: {
    acceptTerms: subscriptionActivationForm.acceptTerms,
    activationCodeFeedback: subscriptionActivationForm.activationCodeFeedback,
    activateLabel,
    activationCode: subscriptionActivationForm.activationCode,
    acceptTermsFeedback: subscriptionActivationForm.acceptTermsFeedback,
    pasteActivationCode: subscriptionActivationForm.pasteActivationCode,
    activationHelp: subscriptionActivationInsertCode,
  },
  directives: {
    validation: validation(feedbackMap),
  },
  props: {
    hideSubmitButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const form = {
      state: false,
      showValidation: false,
      fields: {
        activationCode: {
          required: true,
          state: null,
          value: '',
        },
        terms: {
          required: true,
          state: null,
          value: null,
        },
      },
    };
    return {
      form,
      isLoading: false,
    };
  },
  computed: {
    checkboxLabelClass() {
      // by default, if the value is not null the text will look green or red, therefore we force it to use primary text color
      return this.form.fields.terms.state === null ? '' : 'gl-text-default';
    },
  },
  methods: {
    handleError(error) {
      this.$emit(SUBSCRIPTION_ACTIVATION_FAILURE_EVENT, error.message);
    },
    submit() {
      if (!this.form.state) {
        this.form.showValidation = true;
        this.$emit(SUBSCRIPTION_ACTIVATION_FINALIZED_EVENT);
        return;
      }
      this.form.showValidation = false;
      this.isLoading = true;
      this.$apollo
        .mutate({
          mutation: activateSubscriptionMutation,
          variables: {
            gitlabSubscriptionActivateInput: {
              activationCode: this.form.fields.activationCode.value,
            },
          },
          update: (cache, res) => {
            const errors = getErrorsAsData(res);
            if (errors.length) {
              const [error] = errors;
              if (error.includes(INVALID_ACTIVATION_CODE_SERVER_ERROR)) {
                this.handleError(new Error(INVALID_CODE_ERROR));
                return;
              }
              this.handleError(new Error(error));
              return;
            }
            const license = getLicenseFromData(res);
            if (license) {
              this.$emit(SUBSCRIPTION_ACTIVATION_SUCCESS_EVENT, license);
            }
          },
        })
        .catch((error) => {
          this.handleError(error);
        })
        .finally(() => {
          this.$emit(SUBSCRIPTION_ACTIVATION_FINALIZED_EVENT);
          this.isLoading = false;
        });
    },
  },
};
</script>
<template>
  <gl-form novalidate @submit.prevent="submit">
    <gl-form-group
      :description="$options.i18n.activationHelp"
      :invalid-feedback="form.fields.activationCode.feedback"
      :state="form.fields.activationCode.state"
      data-testid="form-group-activation-code"
    >
      <gl-form-input
        id="activation-code-group"
        v-model.trim="form.fields.activationCode.value"
        v-validation:[form.showValidation]
        class="gl-mb-4"
        data-testid="activation-code-field"
        :disabled="isLoading"
        :placeholder="$options.i18n.pasteActivationCode"
        :state="form.fields.activationCode.state"
        :validation-message="$options.i18n.activationCodeFeedback"
        name="activationCode"
        pattern="\w{24}"
        required
      />
    </gl-form-group>

    <gl-form-group
      class="gl-mb-0"
      :invalid-feedback="form.fields.terms.feedback"
      :state="form.fields.terms.state"
      data-testid="form-group-terms"
    >
      <gl-form-checkbox
        id="subscription-form-terms-check"
        v-model="form.fields.terms.value"
        v-validation:[form.showValidation]
        :state="form.fields.terms.state"
        :validation-message="$options.i18n.acceptTermsFeedback"
        data-testid="subscription-terms-checkbox"
        name="terms"
        required
      >
        <span :class="checkboxLabelClass">
          <gl-sprintf :message="$options.i18n.acceptTerms">
            <template #link="{ content }">
              <promo-page-link path="/terms/" target="_blank">
                {{ content }}
              </promo-page-link>
            </template>
          </gl-sprintf>
        </span>
      </gl-form-checkbox>
    </gl-form-group>

    <gl-button
      v-if="!hideSubmitButton"
      :loading="isLoading"
      category="primary"
      class="js-no-auto-disable gl-mt-6"
      data-testid="activate-button"
      type="submit"
      variant="confirm"
    >
      {{ $options.i18n.activateLabel }}
    </gl-button>
  </gl-form>
</template>
