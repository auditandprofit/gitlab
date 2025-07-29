import Vue from 'vue';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { isExperimentVariant } from '~/experimentation/utils';
import IdentityVerificationWizard from './components/wizard.vue';

export const initIdentityVerification = () => {
  const el = document.getElementById('js-identity-verification');

  if (!el) return false;

  const {
    username,
    email,
    creditCard,
    phoneNumber,
    offerPhoneNumberExemption,
    verificationStatePath,
    phoneSendCodePath,
    phoneVerifyCodePath,
    phoneExemptionPath,
    creditCardVerifyPath,
    creditCardVerifyCaptchaPath,
    arkose,
    arkoseDataExchangePayload,
    successfulVerificationPath,
  } = convertObjectPropsToCamelCase(JSON.parse(el.dataset.data), { deep: true });

  const isLWRExperimentCandidate = isExperimentVariant('lightweight_trial_registration_redesign');

  return new Vue({
    el,
    apolloProvider,
    name: 'IdentityVerificationRoot',
    provide: {
      email,
      creditCard,
      phoneNumber,
      offerPhoneNumberExemption,
      verificationStatePath,
      phoneSendCodePath,
      phoneVerifyCodePath,
      phoneExemptionPath,
      creditCardVerifyPath,
      creditCardVerifyCaptchaPath,
      arkoseConfiguration: arkose,
      arkoseDataExchangePayload,
      successfulVerificationPath,
      isLWRExperimentCandidate,
    },
    render: (createElement) =>
      createElement(IdentityVerificationWizard, {
        props: { username },
      }),
  });
};
