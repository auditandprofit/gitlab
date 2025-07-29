<script>
import {
  GlForm,
  GlButton,
  GlFormInput,
  GlSprintf,
  GlLink,
  GlFormFields,
  GlFormGroup,
  GlFormSelect,
} from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/dist/utils';
import csrf from '~/lib/utils/csrf';
import { __, s__ } from '~/locale';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  COUNTRIES_WITH_STATES_ALLOWED,
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COUNTRY_LABEL,
  LEADS_COUNTRY_PROMPT,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
} from 'ee/vue_shared/leads/constants';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';
import {
  TRIAL_TERMS_TEXT,
  TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
  TRIAL_PRIVACY_STATEMENT,
  TRIAL_COOKIE_POLICY,
  TRIAL_STATE_LABEL,
  TRIAL_STATE_PROMPT,
} from '../constants';

export default {
  name: 'CreateTrialWelcomeForm',
  csrf,
  components: {
    GlForm,
    GlButton,
    GlSprintf,
    GlLink,
    GlFormFields,
    GlFormSelect,
    GlFormGroup,
    GlFormInput,
  },
  props: {
    userData: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
    gtmSubmitEventLabel: {
      type: String,
      required: true,
    },
    namespaceId: {
      type: Number,
      required: false,
      default: null,
    },
    serverValidations: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      countries: [],
      states: [],
      formValues: {},
    };
  },
  computed: {
    showCountry() {
      return !this.$apollo.queries.countries.loading;
    },
    countryOptionsWithDefault() {
      const countriesArray = Array.isArray(this.countries) ? this.countries : [];
      return [
        {
          name: LEADS_COUNTRY_PROMPT,
          id: '',
        },
        ...countriesArray,
      ];
    },
    stateRequired() {
      return COUNTRIES_WITH_STATES_ALLOWED.includes(this.formValues.country);
    },
    showState() {
      return !this.$apollo.queries.states.loading && this.formValues.country && this.stateRequired;
    },
    stateOptionsWithDefault() {
      const statesArray = Array.isArray(this.states) ? this.states : [];
      return [
        {
          name: TRIAL_STATE_PROMPT,
          id: '',
        },
        ...statesArray,
      ];
    },
    fields() {
      const result = {};

      result.first_name = {
        label: LEADS_FIRST_NAME_LABEL,
        groupAttrs: {
          class: 'gl-col-span-12 md:gl-col-span-6',
        },
        inputAttrs: {
          name: 'first_name',
          'data-testid': 'first-name-field',
        },
        validators: [formValidators.required(__('First name is required.'))],
      };

      result.last_name = {
        label: LEADS_LAST_NAME_LABEL,
        groupAttrs: {
          class: 'gl-col-span-12 md:gl-col-span-6',
        },
        inputAttrs: {
          name: 'last_name',
          'data-testid': 'last-name-field',
        },
        validators: [formValidators.required(__('Last name is required.'))],
      };

      result.company_name = {
        label: LEADS_COMPANY_NAME_LABEL,
        groupAttrs: {
          class: 'gl-col-span-12',
        },
        inputAttrs: {
          name: 'company_name',
        },
        validators: [formValidators.required(__('Company name is required.'))],
      };

      if (this.showCountry) {
        result.country = {
          label: LEADS_COUNTRY_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          validators: [formValidators.required(__('Country or region is required.'))],
        };

        if (this.showState) {
          result.state = {
            label: TRIAL_STATE_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12',
            },
            validators: [formValidators.required(__('State or province is required.'))],
          };
        }
      }

      let groupNameValidators = [];
      if (this.namespaceId === null)
        groupNameValidators = [formValidators.required(__('Group name is required.'))];

      result.group_name = {
        label: ' ',
        groupAttrs: {
          class: 'gl-col-span-12',
        },
        inputAttrs: {
          disabled: this.namespaceId !== null,
        },
        validators: groupNameValidators,
      };

      result.project_name = {
        label: ' ',
        groupAttrs: {
          class: 'gl-col-span-12',
        },
        validators: [formValidators.required(__('Project name is required.'))],
      };

      result.namespace_id = {
        groupAttrs: {
          class: 'gl-hidden',
        },
      };

      return result;
    },
  },
  watch: {
    'formValues.country': function handleCountryChange() {
      this.resetSelectedState();
    },
  },
  mounted() {
    this.formValues = {
      first_name: this.userData.firstName,
      last_name: this.userData.lastName,
      company_name: this.userData.companyName,
      country: this.userData.country,
      state: this.userData.state,
      group_name: this.userData.groupName || '',
      project_name: this.userData.projectName || '',
      namespace_id: this.namespaceId,
    };
  },
  methods: {
    onSubmit() {
      trackSaasTrialLeadSubmit(this.gtmSubmitEventLabel, this.userData.emailDomain);
      this.$refs.form.$el.submit();
    },
    resetSelectedState() {
      if (!this.showState) {
        this.formValues.state = '';
      }
    },
    onCompanyNameChange(input, text) {
      input(text);

      this.formValues.group_name = `${text}-${this.$options.i18n.group}`;
      this.formValues.project_name = `${text}-${this.$options.i18n.project}`;
    },
  },
  apollo: {
    countries: {
      query: countriesQuery,
      result(result) {
        if (result.data && result.data.countries) {
          this.countries = Array.isArray(result.data.countries) ? result.data.countries : [];
        }
      },
      error() {
        this.countries = [];
      },
    },
    states: {
      query: statesQuery,
      skip() {
        return !this.formValues.country;
      },
      variables() {
        return {
          countryId: this.formValues.country,
        };
      },
      result(result) {
        if (result.data && result.data.states) {
          this.states = Array.isArray(result.data.states) ? result.data.states : [];
        }
      },
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    buttonText: s__('Trial|Continue to GitLab'),
    termsText: TRIAL_TERMS_TEXT,
    gitlabSubscription: TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
    privacyStatement: TRIAL_PRIVACY_STATEMENT,
    cookiePolicy: TRIAL_COOKIE_POLICY,
    group: __('group'),
    project: __('project'),
  },
  formId: 'create-trial-form',
};
</script>

<template>
  <gl-form
    :id="$options.formId"
    ref="form"
    :action="submitPath"
    method="post"
    class="gl-border-1 gl-border-solid gl-border-gray-100 gl-p-6"
    data-testid="trial-form"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />

    <gl-form-fields
      v-model="formValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-grid md:gl-gap-x-4"
      :server-validations="serverValidations"
      @submit="onSubmit"
    >
      <template #input(company_name)="{ id, value, input = () => {}, blur = () => {} }">
        <gl-form-input
          :id="id"
          name="company_name"
          :value="value"
          @input="onCompanyNameChange(input, $event)"
          @blur="blur"
        />
      </template>

      <template #input(country)>
        <gl-form-select
          id="country"
          v-model="formValues.country"
          name="country"
          :options="countryOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="country-dropdown"
        />
      </template>

      <template #input(state)>
        <gl-form-select
          id="state"
          v-model="formValues.state"
          name="state"
          :options="stateOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="state-dropdown"
        />
      </template>

      <template #input(group_name)="{ id, value = '', input = () => {}, blur = () => {} }">
        <div class="gl-flex">
          <gl-form-group
            class="gl-mb-0 gl-flex-grow"
            :label-description="__('You use groups to organize your projects')"
            :label="__('Group Name')"
            data-testid="group-name-group"
          >
            <gl-form-input
              :id="id"
              name="group_name"
              :value="value"
              :disabled="fields.group_name.inputAttrs.disabled"
              @input="input"
              @blur="blur"
            />
          </gl-form-group>
          <div
            class="gl-z-1 gl-ml-6 gl-mt-2 gl-flex gl-w-11 gl-items-center gl-justify-center gl-rounded-lg gl-bg-gray-50 gl-px-8 gl-text-size-h1-xl gl-font-semibold"
            data-testid="group-name-letter"
          >
            {{ (value.length > 0 ? value : __('Group'))[0].toUpperCase() }}
          </div>
        </div>
      </template>

      <template #input(project_name)="{ id, value, input = () => {}, blur = () => {} }">
        <div class="gl-flex">
          <gl-form-group
            class="gl-mb-0 gl-flex-grow"
            :label-description="__('Projects contain the resources for your repository')"
            :label="__('Project Name')"
            data-testid="project-name-group"
          >
            <gl-form-input
              :id="id"
              name="project_name"
              :value="value"
              @input="input"
              @blur="blur"
            />
          </gl-form-group>
          <div class="gl-relative gl-ml-8 gl-w-11">
            <div
              class="gl-absolute gl-bottom-5 gl-right-8 gl-z-0 gl-h-20 gl-w-6 gl-border-b-2 gl-border-r-2 gl-border-gray-600 gl-border-b-solid gl-border-r-solid"
            ></div>
          </div>
        </div>
      </template>

      <template #input(namespace_id)="{ value }">
        <input type="hidden" :value="value" name="namespace_id" />
      </template>
    </gl-form-fields>

    <gl-button
      type="submit"
      variant="confirm"
      data-testid="continue-button"
      class="js-no-auto-disable gl-w-full"
    >
      {{ $options.i18n.buttonText }}
    </gl-button>

    <div class="gl-mt-4">
      <gl-sprintf :message="$options.i18n.termsText">
        <template #buttonText>{{ $options.i18n.buttonText }}</template>
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
