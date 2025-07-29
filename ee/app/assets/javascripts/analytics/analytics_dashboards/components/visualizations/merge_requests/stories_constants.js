/* eslint-disable @gitlab/require-i18n-strings */
export const throughputTableData = [
  {
    id: '1',
    iid: '1',
    title: 'Update README.md',
    createdAt: '2020-08-06T16:53:50Z',
    mergedAt: '2020-08-06T16:57:53Z',
    webUrl: 'http://127.0.0.1:3001/gitlab-org/gitlab-shell/-/merge_requests/11',
    milestone: { title: '18.0' },
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
    id: '2',
    iid: '2',
    title: 'Add new LICENSE file',
    createdAt: '2020-08-10T16:53:50Z',
    mergedAt: '2020-08-12T16:57:53Z',
    webUrl: 'http://127.0.0.1:3001/gitlab-org/gitlab-shell/-/merge_requests/11',
    milestone: { title: '17.11' },
    assignees: {
      nodes: [
        {
          id: '2',
          avatarUrl: 'https://www.gravatar.com/avatar/asdf23q2de2qdawd2?s=80&d=identicon',
          name: 'Administrator',
          webUrl: 'http://127.0.0.1:3001/root',
        },
      ],
    },
    diffStatsSummary: { additions: 2, deletions: 1 },
    labels: {
      count: 3,
    },
    pipelines: {
      nodes: [],
    },
    commitCount: 0,
    userNotesCount: 10,
    approvedBy: {
      nodes: [],
    },
  },
];
