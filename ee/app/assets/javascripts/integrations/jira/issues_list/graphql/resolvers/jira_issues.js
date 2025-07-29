import { DEFAULT_PAGE_SIZE } from '~/vue_shared/issuable/list/constants';
import { i18n } from '~/issues/list/constants';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

const transformJiraIssueAssignees = (jiraIssue) => {
  return jiraIssue.assignees.map((assignee) => ({
    __typename: 'UserCore',
    ...assignee,
  }));
};

const transformJiraIssueAuthor = (jiraIssue, authorId) => {
  return {
    __typename: 'UserCore',
    ...jiraIssue.author,
    id: authorId,
  };
};

const transformJiraIssueLabels = (jiraIssue) => {
  return jiraIssue.labels.map((label) => ({
    __typename: 'Label',
    ...label,
  }));
};

const transformJiraIssuePageInfo = (responseHeaders = {}) => {
  return {
    __typename: 'JiraIssuesPageInfo',
    page: parseInt(responseHeaders['x-page'], 10) ?? 1,
    total: parseInt(responseHeaders['x-total'], 10) ?? 0,
  };
};

export const transformJiraIssuesREST = (response) => {
  const { headers, data: jiraIssues } = response;

  return {
    __typename: 'JiraIssues',
    errors: [],
    pageInfo: transformJiraIssuePageInfo(headers),
    nodes: jiraIssues.map((rawIssue, index) => {
      const jiraIssue = convertObjectPropsToCamelCase(rawIssue, { deep: true });
      return {
        __typename: 'JiraIssue',
        ...jiraIssue,
        // JIRA issues don't have `id` so we use references.relative
        id: rawIssue.references.relative,
        author: transformJiraIssueAuthor(jiraIssue, index),
        labels: transformJiraIssueLabels(jiraIssue),
        assignees: transformJiraIssueAssignees(jiraIssue),
      };
    }),
  };
};

export default function jiraIssuesResolver(
  _,
  {
    issuesFetchPath,
    page,
    sort,
    state,
    project,
    status,
    authorUsername,
    assigneeUsername,
    labels,
    search,
  },
) {
  return axios
    .get(issuesFetchPath, {
      params: {
        with_labels_details: true,
        per_page: DEFAULT_PAGE_SIZE,
        page,
        sort,
        state,
        project,
        status,
        author_username: authorUsername,
        assignee_username: assigneeUsername,
        labels,
        search,
      },
    })
    .then((res) => {
      return transformJiraIssuesREST(res);
    })
    .catch((error) => {
      return {
        __typename: 'JiraIssues',
        errors: error?.response?.data?.errors || [i18n.errorFetchingIssues],
        pageInfo: transformJiraIssuePageInfo(),
        nodes: [],
      };
    });
}
