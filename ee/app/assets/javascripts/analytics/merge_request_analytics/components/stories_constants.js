/* eslint-disable @gitlab/require-i18n-strings */

export const startDate = new Date('2020-05-01');
export const endDate = new Date('2020-08-01');
export const fullPath = 'gitlab-org/gitlab';

export const throughputChartData = {
  May_2020: { count: 2, totalTimeToMerge: 1234567, __typename: 'MergeRequestConnection' },
  Jun_2020: { count: 4, totalTimeToMerge: 2345678, __typename: 'MergeRequestConnection' },
  Jul_2020: { count: 3, totalTimeToMerge: 3456789, __typename: 'MergeRequestConnection' },
  Aug_2020: { count: 4, totalTimeToMerge: 3456789, __typename: 'MergeRequestConnection' },
  __typename: 'Project',
};

export const throughputChartNoData = {
  May_2020: { count: 0, totalTimeToMerge: 0, __typename: 'MergeRequestConnection' },
  Jun_2020: { count: 0, totalTimeToMerge: 0, __typename: 'MergeRequestConnection' },
  Jul_2020: { count: 0, totalTimeToMerge: 0, __typename: 'MergeRequestConnection' },
  Aug_2020: { count: 0, totalTimeToMerge: 0, __typename: 'MergeRequestConnection' },
  __typename: 'Project',
};

export const throughputTableData = {
  project: {
    id: 'gid://gitlab/Project/278964',
    mergeRequests: {
      pageInfo: {
        hasNextPage: true,
        hasPreviousPage: false,
        startCursor: 'abc',
        endCursor: 'bcd',
      },
      nodes: [
        {
          id: '1',
          iid: '1',
          title: 'Update README.md',
          createdAt: '2020-08-06T16:53:50Z',
          mergedAt: '2020-08-06T16:57:53Z',
          webUrl: 'http://127.0.0.1:3001/gitlab-org/gitlab-shell/-/merge_requests/11',
          milestone: null,
          assignees: {
            nodes: [
              {
                id: '1',
                avatarUrl:
                  'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
                name: 'Administrator',
                webUrl: 'http://127.0.0.1:3001/root',
              },
            ],
          },
          diffStatsSummary: { additions: 2, deletions: 1 },
          labels: {
            count: 0,
          },
          pipelines: {
            nodes: [],
          },
          commitCount: 1,
          userNotesCount: 0,
          approvedBy: {
            nodes: [],
          },
        },
        {
          id: '1',
          iid: '1',
          title: 'Update README.md',
          createdAt: '2020-08-06T16:53:50Z',
          mergedAt: '2020-08-06T16:57:53Z',
          webUrl: 'http://127.0.0.1:3001/gitlab-org/gitlab-shell/-/merge_requests/11',
          milestone: null,
          assignees: {
            nodes: [
              {
                id: '1',
                avatarUrl:
                  'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
                name: 'Administrator',
                webUrl: 'http://127.0.0.1:3001/root',
              },
            ],
          },
          diffStatsSummary: { additions: 2, deletions: 1 },
          labels: {
            count: 0,
          },
          pipelines: {
            nodes: [],
          },
          commitCount: 1,
          userNotesCount: 0,
          approvedBy: {
            nodes: [],
          },
        },
      ],
    },
  },
};

export const throughputTableNoData = {
  project: {
    id: 'gid://gitlab/Project/278964',
    mergeRequests: {
      pageInfo: {
        hasNextPage: true,
        hasPreviousPage: false,
        startCursor: 'abc',
        endCursor: 'bcd',
      },
      nodes: [],
    },
  },
};

export const stats = [
  {
    title: 'Mean time to merge',
    unit: 'days',
    value: '10',
  },
  {
    title: 'MRs per engineer',
    unit: 'MRs per engineer (per month)',
    value: '23',
  },
];

export const noDataStats = [
  {
    title: 'Mean time to merge',
    unit: 'days',
    value: '0',
  },
  {
    title: 'MRs per engineer',
    unit: 'MRs per engineer (per month)',
    value: '0',
  },
];
