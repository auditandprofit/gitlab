import produce from 'immer';
import uniqueId from 'lodash/uniqueId';
import {
  SESSIONS_TABLE_NAME,
  DASHBOARD_SCHEMA_VERSION,
  CATEGORY_SINGLE_STATS,
  CATEGORY_CHARTS,
  CATEGORY_TABLES,
  VISUALIZATION_TYPE_DATA_TABLE,
  VISUALIZATION_TYPE_SINGLE_STAT,
} from 'ee/analytics/analytics_dashboards/constants';
import { DATE_RANGE_FILTER_DIMENSIONS } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';
import { humanize } from '~/lib/utils/text_utility';
import { cloneWithoutReferences } from '~/lib/utils/common_utils';
import getAllCustomizableDashboardsQuery from '../graphql/queries/get_all_customizable_dashboards.query.graphql';
import getCustomizableDashboardQuery from '../graphql/queries/get_customizable_dashboard.query.graphql';
import { TYPENAME_ANALYTICS_DASHBOARD_PANEL } from '../graphql/constants';

/**
 * Given a CubeJS property (e.g. `Sessions.count`), get the schema name (e.g. `Sessions`).
 */
export function getMetricSchema(metric) {
  return metric?.split('.')[0];
}

/**
 * Filters an array of dimensions by schema
 */
export function getDimensionsForSchema(selectedSchema, availableDimensions) {
  if (!selectedSchema) return [];

  return availableDimensions.filter(({ name }) => getMetricSchema(name) === selectedSchema);
}

/**
 * Selects a time dimension for a given schema
 */
export function getTimeDimensionForSchema(selectedSchema, availableTimeDimensions) {
  if (!selectedSchema) return null;

  const timeDimensions = availableTimeDimensions.filter(
    ({ name }) => getMetricSchema(name) === selectedSchema,
  );

  if (timeDimensions.length === 1) {
    // We only allow filtering by a single timeDimension. We expect most of our cubes to only have a single time dimension.
    return timeDimensions.at(0);
  }

  if (selectedSchema === SESSIONS_TABLE_NAME) {
    // Our `Sessions` cube is different, having both `startsAt`, `endsAt` timeDimensions.
    // We want to explicitly select the right dimension for Sessions so have this hardcoded lookup
    const sessionsDimensionName = DATE_RANGE_FILTER_DIMENSIONS[SESSIONS_TABLE_NAME.toLowerCase()];
    return timeDimensions.find(({ name }) => name === sessionsDimensionName);
  }

  // An unknown situation where a cube other than Sessions has more than one timeDimension. Hide it from the UI.
  return null;
}

/**
 * Updates a dashboard detail in cache from getProductAnalyticsDashboard:{slug}
 */
const updateDashboardDetailsApolloCache = ({
  apolloClient,
  dashboard,
  slug,
  fullPath,
  isProject,
  isGroup,
}) => {
  const getDashboardDetailsQuery = {
    query: getCustomizableDashboardQuery,
    variables: {
      fullPath,
      slug,
      isProject,
      isGroup,
    },
  };
  const sourceData = apolloClient.readQuery(getDashboardDetailsQuery);
  if (!sourceData) {
    // Dashboard details not yet in cache, must be a new dashboard, nothing to update
    return;
  }

  const data = produce(sourceData, (draftState) => {
    const { nodes } = isProject
      ? draftState.project.customizableDashboards
      : draftState.group.customizableDashboards;
    const updateIndex = nodes.findIndex((node) => node.slug === slug);

    if (updateIndex < 0) return;

    const updateNode = nodes[updateIndex];

    nodes.splice(updateIndex, 1, {
      ...updateNode,
      ...dashboard,
      panels: {
        ...updateNode.panels,
        nodes:
          dashboard.panels?.map((panel) => {
            const { id, ...panelRest } = panel;
            return { __typename: TYPENAME_ANALYTICS_DASHBOARD_PANEL, ...panelRest };
          }) || [],
      },
    });
  });

  apolloClient.writeQuery({
    ...getDashboardDetailsQuery,
    data,
  });
};

/**
 * Adds/updates a newly created dashboard to the dashboards list cache from getAllCustomizableDashboardsQuery
 */
const updateDashboardsListApolloCache = ({
  apolloClient,
  dashboardSlug,
  dashboard,
  fullPath,
  isProject,
  isGroup,
}) => {
  const getDashboardListQuery = {
    query: getAllCustomizableDashboardsQuery,
    variables: {
      fullPath,
      isProject,
      isGroup,
    },
  };
  const sourceData = apolloClient.readQuery(getDashboardListQuery);
  if (!sourceData) {
    // Dashboard list not yet loaded in cache, nothing to update
    return;
  }

  const data = produce(sourceData, (draftState) => {
    const { panels, ...dashboardWithoutPanels } = dashboard;
    const { nodes } = isProject
      ? draftState.project.customizableDashboards
      : draftState.group.customizableDashboards;

    const updateIndex = nodes.findIndex(({ slug }) => slug === dashboardSlug);

    // Add new dashboard if it doesn't exist
    if (updateIndex < 0) {
      nodes.push(dashboardWithoutPanels);
      return;
    }

    nodes.splice(updateIndex, 1, {
      ...nodes[updateIndex],
      ...dashboardWithoutPanels,
    });
  });

  apolloClient.writeQuery({
    ...getDashboardListQuery,
    data,
  });
};

export const updateApolloCache = ({
  apolloClient,
  slug,
  dashboard,
  fullPath,
  isProject,
  isGroup,
}) => {
  // TODO: modify to support removing dashboards from cache https://gitlab.com/gitlab-org/gitlab/-/issues/425513
  updateDashboardDetailsApolloCache({
    apolloClient,
    dashboard,
    slug,
    fullPath,
    isProject,
    isGroup,
  });
  updateDashboardsListApolloCache({ apolloClient, slug, dashboard, fullPath, isProject, isGroup });
};

/**
 * Get the category key for visualizations by their type. Default is "charts".
 */
export const getVisualizationCategory = (visualization) => {
  if (visualization.type === VISUALIZATION_TYPE_SINGLE_STAT) {
    return CATEGORY_SINGLE_STATS;
  }
  if (visualization.type === VISUALIZATION_TYPE_DATA_TABLE) {
    return CATEGORY_TABLES;
  }
  return CATEGORY_CHARTS;
};

/**
 * Maps a full hydrated dashboard (including GraphQL __typenames, and full visualization definitions) into a slimmed down version that complies with the dashboard schema definition
 */
export const getDashboardConfig = (hydratedDashboard) => {
  const { __typename: dashboardTypename, userDefined, slug, ...dashboardRest } = hydratedDashboard;

  return {
    ...dashboardRest,
    version: DASHBOARD_SCHEMA_VERSION,
    panels: hydratedDashboard.panels.map((panel) => {
      const { __typename: panelTypename, id, ...panelRest } = panel;
      const { __typename: visualizationTypename, ...visualizationRest } = panel.visualization;

      return {
        ...panelRest,
        queryOverrides: panel.queryOverrides ?? {},
        visualization: visualizationRest,
      };
    }),
  };
};

export const getUniquePanelId = () => uniqueId('panel-');

export const createNewVisualizationPanel = (visualization) => ({
  id: getUniquePanelId(),
  title: humanize(visualization.slug),
  gridAttributes: {
    width: 4,
    height: 3,
  },
  queryOverrides: {},
  options: {},
  visualization: cloneWithoutReferences({ ...visualization, errors: null }),
});

/**
 * Validator for the availableVisualizations property
 */
export const availableVisualizationsValidator = ({ loading, hasError, visualizations }) => {
  return (
    typeof loading === 'boolean' && typeof hasError === 'boolean' && Array.isArray(visualizations)
  );
};
