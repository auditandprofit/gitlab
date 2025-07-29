import '~/pages/projects/show/index';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import initVueAlerts from '~/vue_alerts';
import initTierBadgeTrigger from 'ee/groups/init_tier_badge_trigger';
import createDefaultClient from '~/lib/graphql';
import initTargetedMessages from 'ee/admin/init_targeted_message';
import ComplianceInfo from './components/compliance_info.vue';

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

const initComplianceInfo = () => {
  const complianceInfoEl = document.getElementById('js-compliance-info');
  if (!complianceInfoEl) return false;
  const { projectPath, complianceCenterPath, canViewDashboard } = complianceInfoEl.dataset;
  return new Vue({
    el: complianceInfoEl,
    apolloProvider,
    render(h) {
      return h(ComplianceInfo, {
        props: {
          projectPath,
          complianceCenterPath,
          canViewDashboard,
        },
      });
    },
  });
};

initVueAlerts();
initTierBadgeTrigger();
initComplianceInfo();
initTargetedMessages();
