<script>
import { helpPagePath } from '~/helpers/help_page_helper';
import RuleViewFoss from '~/projects/settings/branch_rules/components/view/index.vue';
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import ProjectRules from 'ee/approvals/project_settings/project_rules.vue';
import StatusChecks from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks.vue';
import { I18N } from '~/projects/settings/branch_rules/components/view/constants';

const approvalsHelpDocLink = helpPagePath('user/project/merge_requests/approvals/_index');
const statusChecksHelpDocLink = helpPagePath('user/project/merge_requests/status_checks');

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'EERuleView',
  components: { ApprovalRulesApp, ProjectRules, StatusChecks }, // used in the CE template
  extends: RuleViewFoss,
  i18n: I18N,
  approvalsHelpDocLink,
  statusChecksHelpDocLink,
  inject: {
    approvalRulesPath: {
      default: '',
    },
    statusChecksPath: {
      default: '',
    },
  },
  computed: {
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    statusChecksHeader() {
      return this.$options.i18n.statusChecksHeader;
    },
    // eslint-disable-next-line vue/no-unused-properties -- Used in extended CE template
    statusChecksCount() {
      return this.statusChecks.length;
    },
  },
};
</script>
