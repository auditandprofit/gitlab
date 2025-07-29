<script>
import { GlForm, GlButton, GlFormGroup, GlFormInput, GlSprintf, GlLink } from '@gitlab/ui';
import CountryOrRegionSelector from 'jh_else_ee/trials/components/country_or_region_selector.vue';
import csrf from '~/lib/utils/csrf';
import GlFieldErrors from '~/gl_field_errors';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import {
  TRIAL_PHONE_DESCRIPTION,
  TRIAL_TERMS_TEXT,
  TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
  TRIAL_PRIVACY_STATEMENT,
  TRIAL_COOKIE_POLICY,
} from '../constants';

export default {
  name: 'TrialCreateLeadForm',
  csrf,
  components: {
    GlForm,
    GlButton,
    GlFormGroup,
    GlFormInput,
    CountryOrRegionSelector,
    GlSprintf,
    GlLink,
  },
  directives: {
    autofocusonshow,
  },
  inject: ['user', 'submitPath', 'gtmSubmitEventLabel', 'submitButtonText'],
  props: {
    border: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return this.user;
  },
  mounted() {
    // eslint-disable-next-line no-new
    new GlFieldErrors(this.$el);
  },
  methods: {
    onSubmit() {
      trackSaasTrialLeadSubmit(this.gtmSubmitEventLabel, this.user.emailDomain);
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    phoneNumberDescription: TRIAL_PHONE_DESCRIPTION,
    termsText: TRIAL_TERMS_TEXT,
    gitlabSubscription: TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
    privacyStatement: TRIAL_PRIVACY_STATEMENT,
    cookiePolicy: TRIAL_COOKIE_POLICY,
  },
};
</script>

<template>
  <gl-form
    :action="submitPath"
    method="post"
    :class="{ 'gl-border-1 gl-border-solid gl-border-gray-100 gl-p-6': border }"
    data-testid="lead-form"
    @submit="onSubmit"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <div v-show="showNameFields" class="gl-mt-5 gl-flex gl-flex-col sm:gl-flex-row">
      <gl-form-group
        :label="$options.i18n.firstNameLabel"
        label-size="sm"
        label-for="first_name"
        class="gl-mr-5 gl-w-full sm:gl-w-1/2"
      >
        <gl-form-input
          id="first_name"
          :value="firstName"
          name="first_name"
          data-testid="first-name-field"
          required
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.lastNameLabel"
        label-size="sm"
        label-for="last_name"
        class="gl-w-full sm:gl-w-1/2"
      >
        <gl-form-input
          id="last_name"
          :value="lastName"
          name="last_name"
          data-testid="last-name-field"
          required
        />
      </gl-form-group>
    </div>
    <gl-form-group :label="$options.i18n.companyNameLabel" label-size="sm" label-for="company_name">
      <gl-form-input
        id="company_name"
        :value="companyName"
        name="company_name"
        data-testid="company-name-field"
        required
      />
    </gl-form-group>
    <country-or-region-selector :country="country" :state="state" required />
    <gl-form-group
      :label="$options.i18n.phoneNumberLabel"
      label-size="sm"
      :optional-text="__('(optional)')"
      label-for="phone_number"
      optional
    >
      <gl-form-input
        id="phone_number"
        :value="phoneNumber"
        name="phone_number"
        type="tel"
        data-testid="phone-number-field"
        pattern="^(\+)*[0-9\-\s]+$"
        :title="$options.i18n.phoneNumberDescription"
      />
    </gl-form-group>
    <gl-button type="submit" variant="confirm" data-testid="continue-button" class="gl-w-full">
      {{ submitButtonText }}
    </gl-button>

    <div class="gl-mt-4">
      <gl-sprintf :message="$options.i18n.termsText">
        <template #buttonText>{{ submitButtonText }}</template>
        <template #gitlabSubscriptionAgreement>
          <gl-link :href="$options.i18n.gitlabSubscription.url" target="_blank">
            {{ $options.i18n.gitlabSubscription.text }}
          </gl-link>
        </template>
        <template #privacyStatement>
          <gl-link :href="$options.i18n.privacyStatement.url" target="_blank">
            {{ $options.i18n.privacyStatement.text }}
          </gl-link>
        </template>
        <template #cookiePolicy>
          <gl-link :href="$options.i18n.cookiePolicy.url" target="_blank">
            {{ $options.i18n.cookiePolicy.text }}
          </gl-link>
        </template>
      </gl-sprintf>
    </div>
  </gl-form>
</template>
