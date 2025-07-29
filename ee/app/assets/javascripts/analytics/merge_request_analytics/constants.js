import { __, s__ } from '~/locale';

export const DEFAULT_NUMBER_OF_DAYS = 365;
export const STAT_LOADER_HEIGHT = 46;
export const PER_PAGE = 20;
export const ASSIGNEES_VISIBLE = 2;
export const AVATAR_SIZE = 24;
export const EXCLUDED_DATA_KEYS = ['__typename'];

export const THROUGHPUT_CHART_STRINGS = {
  CHART_TITLE: __('Throughput'),
  Y_AXIS_TITLE: __('Merge Requests merged'),
  X_AXIS_TITLE: __('Month'),
  CHART_DESCRIPTION: __('The number of merge requests merged by month.'),
  NO_DATA: __('There is no chart data available.'),
  ERROR_FETCHING_DATA: __(
    'There was an error while fetching the chart data. Please refresh the page to try again.',
  ),
  MTTM: __('Mean time to merge'),
};

export const THROUGHPUT_TABLE_STRINGS = {
  NO_DATA: __('There is no table data available.'),
  ERROR_FETCHING_DATA: __(
    'There was an error while fetching the table data. Please refresh the page to try again.',
  ),
};

export const MERGE_REQUEST_ID_PREFIX = '!';

export const LINE_CHANGE_SYMBOLS = {
  ADDITIONS: '+',
  DELETIONS: '-',
};

export const THROUGHPUT_TABLE_TEST_IDS = {
  TABLE_HEADERS: 'header',
  MERGE_REQUEST_DETAILS: 'detailsCol',
  LABEL_DETAILS: 'labelDetails',
  DATE_MERGED: 'dateMergedCol',
  TIME_TO_MERGE: 'timeToMergeCol',
  MILESTONE: 'milestoneCol',
  PIPELINES: 'pipelinesCol',
  LINE_CHANGES: 'lineChangesCol',
  ASSIGNEES: 'assigneesCol',
  COMMITS: 'commitsCol',
  COMMENT_COUNT: 'commentCount',
  APPROVED: 'approvedStatus',
};

export const PIPELINE_STATUS_ICON_CLASSES = {
  status_success: 'gl-text-success',
  status_failed: 'gl-text-danger',
  status_pending: 'gl-text-warning',
  default: 'gl-text-grey-500',
};

export const UNITS = {
  DAYS: __('days'),
};

export const MAX_LABEL_SUGGESTIONS = 100;

export const INITIAL_PAGINATION_STATE = {
  currentPage: 1,
  prevPageCursor: '',
  nextPageCursor: '',
  firstPageSize: PER_PAGE,
  lastPageSize: null,
};

const TH_COMMON_OPTS = {
  tdClass: 'merge-request-analytics-td',
  thAttr: { 'data-testid': THROUGHPUT_TABLE_TEST_IDS.TABLE_HEADERS },
};

export const THROUGHPUT_TABLE_HEADER_FIELDS = [
  {
    key: 'mr_details',
    label: s__('MergeRequestAnalytics|Merge Request'),
    ...TH_COMMON_OPTS,
  },
  {
    key: 'date_merged',
    label: s__('MergeRequestAnalytics|Date Merged'),
    ...TH_COMMON_OPTS,
  },
  {
    key: 'time_to_merge',
    label: s__('MergeRequestAnalytics|Time to merge'),
    ...TH_COMMON_OPTS,
  },
  {
    key: 'milestone',
    label: s__('MergeRequestAnalytics|Milestone'),
    ...TH_COMMON_OPTS,
  },
  {
    key: 'commits',
    label: __('Commits'),
    ...TH_COMMON_OPTS,
  },
  {
    key: 'pipelines',
    label: s__('MergeRequestAnalytics|Pipelines'),
    ...TH_COMMON_OPTS,
  },
  {
    key: 'line_changes',
    label: s__('MergeRequestAnalytics|Line changes'),
    ...TH_COMMON_OPTS,
  },
  {
    key: 'assignees',
    label: s__('MergeRequestAnalytics|Assignees'),
    ...TH_COMMON_OPTS,
  },
];
