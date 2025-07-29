import Vue from 'vue';
import apolloProvider from 'ee/security_dashboard/graphql/provider';
import App from 'ee/vulnerabilities/components/vulnerability.vue';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import createRouter from 'ee/security_dashboard/router';

export default (el) => {
  if (!el) {
    return null;
  }

  const { canViewFalsePositive, projectFullPath, defaultBranch, customizeJiraIssueEnabled } =
    el.dataset;

  const vulnerabilityJson = JSON.parse(el.dataset.vulnerability);
  const dismissalDescriptions = vulnerabilityJson.dismissal_descriptions;

  const vulnerability = convertObjectPropsToCamelCase(JSON.parse(el.dataset.vulnerability), {
    deep: true,
  });

  const router = createRouter();

  return new Vue({
    el,
    name: 'VulnerabilityRoot',
    router,
    apolloProvider,
    provide: {
      reportType: vulnerability.reportType,
      newIssueUrl: vulnerability.newIssueUrl,
      commitPathTemplate: el.dataset.commitPathTemplate,
      vulnerabilityId: vulnerability.id,
      issueTrackingHelpPath: vulnerability.issueTrackingHelpPath,
      permissionsHelpPath: vulnerability.permissionsHelpPath,
      createJiraIssueUrl: vulnerability.createJiraIssueUrl,
      relatedJiraIssuesPath: vulnerability.relatedJiraIssuesPath,
      relatedJiraIssuesHelpPath: vulnerability.relatedJiraIssuesHelpPath,
      jiraIntegrationSettingsPath: vulnerability.jiraIntegrationSettingsPath,
      archivalInformation: vulnerability.archivalInformation,
      canViewFalsePositive: parseBoolean(canViewFalsePositive),
      customizeJiraIssueEnabled: parseBoolean(customizeJiraIssueEnabled),
      projectFullPath,
      defaultBranch,
      dismissalDescriptions,
    },
    render: (h) =>
      h(App, {
        props: { initialVulnerability: vulnerability },
      }),
  });
};
