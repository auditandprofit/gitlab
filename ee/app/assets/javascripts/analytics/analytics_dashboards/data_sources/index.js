/**
 * Imports an analytics dashboard datasource
 *
 * A datasource is a file that exports a single default `fetch` function with the following signature:
 *
 * @param {Object} options - The options object
 * @param {string} options.title - The title of the project
 * @param {number} options.projectId - The ID of the project
 * @param {string} options.namespace - // the namespace full path
 * @param {boolean} options.isProject - If `true` this dashboard is project-level, otherwise group-level
 * @param {Object} options.query - The query object for fetching data
 * @param {Object} [options.queryOverrides={}] - Optional overrides for the base query.  Refer to `QueryOverrides` in `ee/app/validators/json_schemas/analytics_visualization.json`. This can also be changed by the visualisation at runtime.
 * @param {string} options.visualizationType - The type of visualization to render (line chart, table, etc.). Refer to `AnalyticsVisualization.type` in `ee/app/validators/json_schemas/analytics_visualization.json`
 * @param {Object} options.visualizationOptions - Additional options for customizing the visualization Refer to `Options` in `ee/app/validators/json_schemas/analytics_visualization.json`
 * @param {Object} [options.filters={}] - Optional filters to apply to the query. The filter object contains:
 *
 *   - startDate {Date} - Start date for the filter
 *   - endDate {Date} - End date for the filter
 *   - dateRangeOption {string} - Selected date range option key
 *   - filterAnonUsers {boolean} - Whether to filter anonymous users
 *   - searchFilters {Object} - Parsed search filters
 *   - projectFullPath {string|null} - Project full path or null
 *
 * @param {Function} [options.onRequestDelayed=()=>{}] - Callback function when request is delayed. It can trigger a loading spinner in the panel
 * @param {Function} [options.setAlerts=()=>{}] - Callback function to set alerts
 * @param {Function} [options.setVisualizationOverrides=()=>{}] - Callback function to set visualization options before render but after the data fetch, allowing us to include fetched data in the visualization options
 *
 * @returns {Promise<Array|Object>} The formatted data for the specified visualization type
 *
 * @throws {Error} If the API request fails
 *
 * export default async function fetch(options);
 *
 */

export default {
  cube_analytics: () => import('./cube_analytics'),
  value_stream: () => import('./value_stream'),
  usage_overview: () => import('./usage_overview'),
  usage_count: () => import('./usage_count'),
  dora_metrics: () => import('./dora_metrics'),
  dora_metrics_by_project: () => import('./dora_metrics_by_project'),
  ai_impact_over_time: () => import('./ai_impact_over_time'),
  contributions: () => import('./contributions'),
  namespace_metadata: () => import('./namespace_metadata'),
  merge_requests: () => import('./merge_requests'),
  merge_request_counts: () => import('./merge_request_counts'),
  mean_time_to_merge: () => import('./mean_time_to_merge'),
};
