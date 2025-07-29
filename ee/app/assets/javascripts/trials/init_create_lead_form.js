import Vue from 'vue';
import TrialCreateLeadForm from 'ee/trials/components/trial_create_lead_form.vue';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';

export const initTrialCreateLeadForm = (gtmSubmitEventLabel, border = false) => {
  const el = document.querySelector('#js-trial-create-lead-form');

  if (!el) {
    return false;
  }

  const {
    submitPath,
    firstName,
    lastName,
    showNameFields,
    companyName,
    country,
    state,
    phoneNumber,
    submitButtonText,
    emailDomain,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      user: {
        firstName,
        lastName,
        showNameFields: parseBoolean(showNameFields),
        companyName,
        country: country || '',
        state: state || '',
        phoneNumber,
        emailDomain,
      },
      submitPath,
      gtmSubmitEventLabel,
      submitButtonText,
    },
    render(createElement) {
      return createElement(TrialCreateLeadForm, {
        props: {
          border,
        },
      });
    },
  });
};
