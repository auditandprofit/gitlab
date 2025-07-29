import Vue from 'vue';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import CentralizedSecurityPolicyManagement from './components/centralized_security_policy_management.vue';

export const initCentralizedSecurityPolicyManagement = () => {
  const el = document.getElementById('js-centralized_security_policy_management');

  if (!el) return false;

  const { centralizedSecurityPolicyGroupId, formId, newGroupPath } = el.dataset;

  return new Vue({
    apolloProvider,
    el,
    name: 'CentralizedSecurityPolicyManagementRoot',
    render(createElement) {
      return createElement(CentralizedSecurityPolicyManagement, {
        props: {
          formId,
          initialSelectedGroupId: parseInt(centralizedSecurityPolicyGroupId, 10),
          newGroupPath,
        },
      });
    },
  });
};
