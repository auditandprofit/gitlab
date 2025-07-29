import VueRouter from 'vue-router';

import { joinPaths } from '~/lib/utils/url_utility';

import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  ROUTE_NEW_FRAMEWORK,
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_NEW_FRAMEWORK_SUCCESS,
  ROUTE_BLANK_FRAMEWORK,
  ROUTE_EXPORT_FRAMEWORK,
  ROUTE_DASHBOARD,
} from './constants';

import MainLayout from './components/main_layout.vue';

import ComplianceDashboard from './components/dashboard/compliance_dashboard.vue';
import ViolationsReport from './components/violations_report/violations_report.vue';
import FrameworksReport from './components/frameworks_report/report.vue';
import EditFramework from './components/frameworks_report/edit_framework/edit_framework.vue';
import ProjectsReport from './components/projects_report/report.vue';
import NewFramework from './components/frameworks_report/new_framework/new_framework.vue';
import StandardsReport from './components/standards_adherence_report/report.vue';
import NewFrameworkSuccess from './components/frameworks_report/edit_framework/new_framework_success.vue';

export function createRouter(basePath, props) {
  const {
    groupPath,
    groupName,
    groupComplianceCenterPath,
    projectId,
    projectPath,
    projectName,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorComplianceCenterPath,
    routes: availableRoutes,
  } = props;

  const availableTabRoutes = [
    {
      path: ROUTE_DASHBOARD,
      name: ROUTE_DASHBOARD,
      component: ComplianceDashboard,
      props: {
        groupPath,
        rootAncestorPath,
      },
    },
    {
      path: ROUTE_STANDARDS_ADHERENCE,
      name: ROUTE_STANDARDS_ADHERENCE,
      component: StandardsReport,
      props: {
        groupPath,
        projectPath,
        rootAncestorPath,
      },
    },
    {
      path: ROUTE_VIOLATIONS,
      name: ROUTE_VIOLATIONS,
      component: ViolationsReport,
      props: {
        groupPath,
        projectPath,
      },
    },
    {
      path: ROUTE_FRAMEWORKS,
      name: ROUTE_FRAMEWORKS,
      component: FrameworksReport,
      props: {
        groupPath,
        projectPath,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
    },
    {
      path: ROUTE_PROJECTS,
      name: ROUTE_PROJECTS,
      component: ProjectsReport,
      props: {
        groupPath,
        groupName,
        groupComplianceCenterPath,
        projectId,
        projectPath,
        projectName,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
    },
  ].filter(({ name }) => availableRoutes.includes(name));

  const defaultRoute = availableTabRoutes[0].name;

  const routes = [
    {
      path: `/${ROUTE_FRAMEWORKS}/new`,
      name: ROUTE_NEW_FRAMEWORK,
      component: NewFramework,
    },
    {
      path: '/frameworks/blank',
      name: ROUTE_BLANK_FRAMEWORK,
      component: EditFramework,
    },
    {
      path: `/${ROUTE_FRAMEWORKS}/new/success`,
      name: ROUTE_NEW_FRAMEWORK_SUCCESS,
      component: NewFrameworkSuccess,
    },
    {
      path: `/${ROUTE_FRAMEWORKS}/:id`,
      name: ROUTE_EDIT_FRAMEWORK,
      component: EditFramework,
    },
    {
      path: '/',
      component: MainLayout,
      props: {
        availableTabs: availableRoutes,
        projectPath,
        groupPath,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
      children: [...availableTabRoutes, { path: '*', redirect: { name: defaultRoute } }],
    },
    {
      name: ROUTE_EXPORT_FRAMEWORK,
      path: '/frameworks/:id.json',
    },
  ];

  return new VueRouter({
    mode: 'history',
    base: joinPaths(gon.relative_url_root || '', basePath),
    routes,
  });
}
