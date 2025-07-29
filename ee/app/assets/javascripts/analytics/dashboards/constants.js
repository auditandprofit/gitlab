import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  MERGE_REQUEST_METRICS,
  CONTRIBUTOR_METRICS,
  UNITS,
} from '~/analytics/shared/constants';

export const SUPPORTED_DORA_METRICS = [
  DORA_METRICS.DEPLOYMENT_FREQUENCY,
  DORA_METRICS.LEAD_TIME_FOR_CHANGES,
  DORA_METRICS.TIME_TO_RESTORE_SERVICE,
  DORA_METRICS.CHANGE_FAILURE_RATE,
];

export const SUPPORTED_FLOW_METRICS = [
  FLOW_METRICS.LEAD_TIME,
  FLOW_METRICS.CYCLE_TIME,
  FLOW_METRICS.ISSUES,
  FLOW_METRICS.ISSUES_COMPLETED,
  FLOW_METRICS.DEPLOYS,
  FLOW_METRICS.MEDIAN_TIME_TO_MERGE,
];

export const SUPPORTED_MERGE_REQUEST_METRICS = [MERGE_REQUEST_METRICS.THROUGHPUT];

export const SUPPORTED_VULNERABILITY_METRICS = [
  VULNERABILITY_METRICS.CRITICAL,
  VULNERABILITY_METRICS.HIGH,
];

export const SUPPORTED_CONTRIBUTOR_METRICS = [CONTRIBUTOR_METRICS.COUNT];

export const DORA_TABLE_METRICS = {
  [DORA_METRICS.DEPLOYMENT_FREQUENCY]: {
    label: s__('DORA4Metrics|Deployment frequency'),
    units: UNITS.PER_DAY,
  },
  [DORA_METRICS.LEAD_TIME_FOR_CHANGES]: {
    label: s__('DORA4Metrics|Lead time for changes'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [DORA_METRICS.TIME_TO_RESTORE_SERVICE]: {
    label: s__('DORA4Metrics|Time to restore service'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [DORA_METRICS.CHANGE_FAILURE_RATE]: {
    label: s__('DORA4Metrics|Change failure rate'),
    invertTrendColor: true,
    units: UNITS.PERCENT,
  },
};

export const TABLE_METRICS = {
  ...DORA_TABLE_METRICS,
  [FLOW_METRICS.LEAD_TIME]: {
    label: s__('DORA4Metrics|Lead time'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [FLOW_METRICS.CYCLE_TIME]: {
    label: s__('DORA4Metrics|Cycle time'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [FLOW_METRICS.ISSUES]: {
    label: s__('DORA4Metrics|Issues created'),
    units: UNITS.COUNT,
  },
  [FLOW_METRICS.ISSUES_COMPLETED]: {
    label: s__('DORA4Metrics|Issues closed'),
    units: UNITS.COUNT,
    valueLimit: {
      max: 10001,
      mask: '10000+',
      description: s__(
        'DORA4Metrics|This is a lower-bound approximation. Your group has too many issues and MRs to calculate in real time.',
      ),
    },
  },
  [FLOW_METRICS.DEPLOYS]: {
    label: s__('DORA4Metrics|Deploys'),
    units: UNITS.COUNT,
  },
  [MERGE_REQUEST_METRICS.THROUGHPUT]: {
    label: s__('DORA4Metrics|Merge request throughput'),
    units: UNITS.COUNT,
  },
  [FLOW_METRICS.MEDIAN_TIME_TO_MERGE]: {
    label: s__('DORA4Metrics|Median time to merge'),
    invertTrendColor: true,
    units: UNITS.DAYS,
  },
  [CONTRIBUTOR_METRICS.COUNT]: {
    label: s__('DORA4Metrics|Contributor count'),
    units: UNITS.COUNT,
  },
  [VULNERABILITY_METRICS.CRITICAL]: {
    label: s__('DORA4Metrics|Critical vulnerabilities over time'),
    invertTrendColor: true,
    units: UNITS.COUNT,
  },
  [VULNERABILITY_METRICS.HIGH]: {
    label: s__('DORA4Metrics|High vulnerabilities over time'),
    invertTrendColor: true,
    units: UNITS.COUNT,
  },
};

export const METRICS_WITH_NO_TREND = [VULNERABILITY_METRICS.CRITICAL, VULNERABILITY_METRICS.HIGH];
export const METRICS_WITH_LABEL_FILTERING = [
  FLOW_METRICS.ISSUES,
  FLOW_METRICS.ISSUES_COMPLETED,
  FLOW_METRICS.CYCLE_TIME,
  FLOW_METRICS.LEAD_TIME,
  MERGE_REQUEST_METRICS.THROUGHPUT,
];
export const METRICS_WITHOUT_LABEL_FILTERING = Object.keys(TABLE_METRICS).filter(
  (metric) => !METRICS_WITH_LABEL_FILTERING.includes(metric),
);

export const DASHBOARD_SURVEY_LINK =
  'https://gitlab.fra1.qualtrics.com/jfe/form/SV_50guMGNU2HhLeT4';
export const DASHBOARD_LOADING_FAILURE = s__('DORA4Metrics|Some metric comparisons failed to load');
export const DASHBOARD_LABELS_LOAD_ERROR = s__(
  'DORA4Metrics|Failed to load labels matching the filter: %{labels}',
);
export const RESTRICTED_METRIC_ERROR = s__(
  'DORA4Metrics|You have insufficient permissions to view',
);
export const GENERIC_DASHBOARD_ERROR = s__('DORA4Metrics|Failed to load dashboard panel.');
export const UNSUPPORTED_PROJECT_NAMESPACE_ERROR = s__(
  'DORA4Metrics|This visualization is not supported for project namespaces.',
);
export const DASHBOARD_NO_DATA_FOR_GROUP = s__(
  'DORA4Metrics|No data available for Group: %{fullPath}',
);

export const CHART_GRADIENT = ['#499767', '#5252B5'];
export const CHART_GRADIENT_INVERTED = [...CHART_GRADIENT].reverse();
export const CHART_LOADING_FAILURE = s__('DORA4Metrics|Some metric charts failed to load');

export const CHART_TOOLTIP_UNITS = {
  [UNITS.COUNT]: undefined,
  [UNITS.DAYS]: __('days'),
  [UNITS.PER_DAY]: __('/day'),
  [UNITS.PERCENT]: '%',
};

export const ALERT_TEXT = s__(
  'DORA4Metrics|To help us improve the Value Stream Management Dashboard, please share feedback about your experience in this %{linkStart}survey%{linkEnd}.',
);

export const BACKGROUND_AGGREGATION_WARNING_TITLE = s__(
  'DORA4Metrics|Background aggregation not enabled',
);

export const ENABLE_BACKGROUND_AGGREGATION_WARNING_TEXT = s__(
  'DORA4Metrics|To see usage overview, you must %{linkStart}enable background aggregation%{linkEnd}.',
);

export const BACKGROUND_AGGREGATION_DOCS_LINK = helpPagePath(
  'user/analytics/value_streams_dashboard.html',
  { anchor: 'enable-or-disable-overview-background-aggregation' },
);

export const BUILT_IN_PRODUCT_ANALYTICS_DASHBOARDS = ['behavior', 'audience'];

export const PRODUCT_ANALYTICS_DASHBOARD_FEEDBACK_CALLOUT_ID =
  'product_analytics_dashboard_feedback';
export const PRODUCT_ANALYTICS_DASHBOARD_SURVEY_LINK =
  'https://gitlab.fra1.qualtrics.com/jfe/form/SV_4G9Mp4aDd1o8kpo';
