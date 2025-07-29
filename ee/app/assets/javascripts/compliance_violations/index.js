import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import ViolationDetailsApp from './components/compliance_violation_details_app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initDetailsApp = () => {
  const el = document.querySelector('#js-project-violation-details');

  if (!el) {
    return false;
  }

  const { violationId, complianceCenterPath } = el.dataset;

  return new Vue({
    el,
    name: 'ComplianceViolationDetailsRoot',
    apolloProvider,
    render(createElement) {
      return createElement(ViolationDetailsApp, { props: { violationId, complianceCenterPath } });
    },
  });
};
