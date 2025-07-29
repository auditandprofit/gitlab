import Vue from 'vue';
import ReportNotConfiguredProject from 'ee/security_dashboard/components/project/report_not_configured_project.vue';
import ReportNotConfiguredGroup from 'ee/security_dashboard/components/group/report_not_configured_group.vue';
import ReportNotConfiguredInstance from 'ee/security_dashboard/components/instance/report_not_configured_instance.vue';
import {
  DASHBOARD_TYPE_GROUP,
  DASHBOARD_TYPE_INSTANCE,
  DASHBOARD_TYPE_PROJECT,
} from 'ee/security_dashboard/constants';
import { parseBoolean } from '~/lib/utils/common_utils';
import groupVulnerabilityGradesQuery from 'ee/security_dashboard/graphql/queries/group_vulnerability_grades.query.graphql';
import groupVulnerabilityHistoryQuery from 'ee/security_dashboard/graphql/queries/group_vulnerability_history.query.graphql';
import instanceVulnerabilityGradesQuery from 'ee/security_dashboard/graphql/queries/instance_vulnerability_grades.query.graphql';
import instanceVulnerabilityHistoryQuery from 'ee/security_dashboard/graphql/queries/instance_vulnerability_history.query.graphql';
import SecurityDashboard from './components/shared/security_dashboard.vue';
import ProjectSecurityCharts from './components/project/project_security_dashboard.vue';
import UnavailableState from './components/shared/empty_states/unavailable_state.vue';
import apolloProvider from './graphql/provider';

export default async (el, dashboardType) => {
  if (!el) {
    return null;
  }

  if (el.dataset.isUnavailable) {
    return new Vue({
      el,
      render(createElement) {
        return createElement(UnavailableState, {
          props: { svgPath: el.dataset.emptyStateSvgPath },
        });
      },
    });
  }

  const {
    emptyStateSvgPath,
    groupFullPath,
    projectFullPath,
    securityConfigurationPath,
    securityDashboardEmptySvgPath,
    instanceDashboardSettingsPath,
    vulnerabilitiesPdfExportEndpoint,
  } = el.dataset;

  const hasProjects = parseBoolean(el.dataset.hasProjects);
  const hasVulnerabilities = parseBoolean(el.dataset.hasVulnerabilities);
  const hideThirdPartyOffers = parseBoolean(el.dataset.hideThirdPartyOffers);
  const provide = {
    emptyStateSvgPath,
    groupFullPath,
    projectFullPath,
    securityConfigurationPath,
    securityDashboardEmptySvgPath,
    instanceDashboardSettingsPath,
    vulnerabilitiesPdfExportEndpoint,
    dashboardType,
  };

  let props;
  let component;

  if (dashboardType === DASHBOARD_TYPE_GROUP) {
    const isGroupSecurityDashboardNewEnabled = gon.features.groupSecurityDashboardNew;

    if (!hasProjects) {
      component = ReportNotConfiguredGroup;
    } else if (isGroupSecurityDashboardNewEnabled) {
      const { default: GroupSecurityDashboardNew } = await import(
        './components/shared/group_security_dashboard_new.vue'
      );
      component = GroupSecurityDashboardNew;
    } else {
      component = SecurityDashboard;
    }

    props = {
      historyQuery: groupVulnerabilityHistoryQuery,
      gradesQuery: groupVulnerabilityGradesQuery,
      showExport: true,
    };
  } else if (dashboardType === DASHBOARD_TYPE_INSTANCE) {
    component = hasProjects ? SecurityDashboard : ReportNotConfiguredInstance;
    props = {
      historyQuery: instanceVulnerabilityHistoryQuery,
      gradesQuery: instanceVulnerabilityGradesQuery,
    };
  } else if (dashboardType === DASHBOARD_TYPE_PROJECT) {
    const isProjectSecurityDashboardNewEnabled = gon.features.projectSecurityDashboardNew;

    if (!hasVulnerabilities) {
      component = ReportNotConfiguredProject;
    } else if (isProjectSecurityDashboardNewEnabled) {
      const { default: ProjectSecurityDashboardNew } = await import(
        './components/shared/project_security_dashboard_new.vue'
      );

      component = ProjectSecurityDashboardNew;
    } else {
      component = ProjectSecurityCharts;
    }
    props = {
      projectFullPath,
      shouldShowPromoBanner: !hideThirdPartyOffers,
    };
  }

  return new Vue({
    el,
    name: 'SecurityDashboardRoot',
    apolloProvider,
    provide,
    render(createElement) {
      return createElement(component, { props });
    },
  });
};
